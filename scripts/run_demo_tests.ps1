#===----------------------------------------------------------------------===#
#
# Part of the Zanna project, under the GNU GPL v3.
# See LICENSE for license information.
#
#===----------------------------------------------------------------------===#
#
# File: scripts/run_demo_tests.ps1
# Purpose: Manifest-driven test runner for every demo in this repository,
#          driven by an existing Zanna binary (native Windows entry point).
# Key invariants:
#   - The runner never configures, builds, or invokes CMake/CTest.
#   - Row semantics, lane selection, and pass criteria mirror
#     run_demo_tests.sh exactly.
#   - run-script rows referencing *.sh resolve to the sibling *.ps1.
# Ownership/Lifetime: GUID-named temporary output files are always removed.
# Cross-platform touchpoints: run_demo_tests.sh is the POSIX entry point.
# Links: demo_tests.tsv, run_demo_tests.sh, README.md
#
#===----------------------------------------------------------------------===#

[CmdletBinding()]
param(
    [switch]$Fast,
    [switch]$Perf,
    [switch]$List,
    [string[]]$Demo = @(),
    [string]$Zanna = ""
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = [IO.Path]::GetFullPath((Join-Path $scriptDir ".."))

$manifestPath = [Environment]::GetEnvironmentVariable("ZANNA_DEMO_TESTS_MANIFEST", "Process")
if ([string]::IsNullOrWhiteSpace($manifestPath)) {
    $manifestPath = Join-Path $root "demo_tests.tsv"
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    [Console]::Error.WriteLine("error: demo test manifest not found: $manifestPath")
    exit 1
}

$zannaSetting = $Zanna
if ([string]::IsNullOrWhiteSpace($zannaSetting)) {
    $zannaSetting = [Environment]::GetEnvironmentVariable("ZANNA_BIN", "Process")
}
if ([string]::IsNullOrWhiteSpace($zannaSetting)) {
    $nestedDefault = Join-Path $root "..\build\src\tools\zanna\zanna.exe"
    if (Test-Path -LiteralPath $nestedDefault -PathType Leaf) {
        $zannaSetting = $nestedDefault
    } else {
        $zannaSetting = "zanna"
    }
}
if (Test-Path -LiteralPath $zannaSetting -PathType Leaf) {
    $zannaBin = (Resolve-Path -LiteralPath $zannaSetting).Path
} else {
    $command = Get-Command $zannaSetting -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        [Console]::Error.WriteLine("demo tests: Zanna binary not found: $zannaSetting")
        [Console]::Error.WriteLine("Set ZANNA_BIN to an existing zanna executable; this runner never builds it.")
        exit 1
    }
    $zannaBin = $command.Source
}

$headless = [Environment]::GetEnvironmentVariable("ZANNA_DEMOS_HEADLESS", "Process") -eq "1"

$output = Join-Path ([IO.Path]::GetTempPath()) `
    ("zannademos-test-{0}.txt" -f [Guid]::NewGuid().ToString("N"))
$errorOutput = "$output.stderr"

function Invoke-RowProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$NativeArguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [Parameter(Mandatory = $true)][hashtable]$RowEnvironment
    )

    Remove-Item -LiteralPath $output, $errorOutput -Force -ErrorAction SilentlyContinue
    $saved = @{}
    foreach ($key in $RowEnvironment.Keys) {
        $saved[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
        [Environment]::SetEnvironmentVariable($key, [string]$RowEnvironment[$key], "Process")
    }
    try {
        $startArguments = @($NativeArguments | ForEach-Object {
                $value = [string]$_
                if ($value -match '[\s"]') { '"' + $value.Replace('"', '\"') + '"' } else { $value }
            })
        $process = Start-Process -FilePath $FilePath -ArgumentList $startArguments `
            -WorkingDirectory $WorkingDirectory `
            -RedirectStandardOutput $output -RedirectStandardError $errorOutput `
            -NoNewWindow -PassThru
        if ($TimeoutSeconds -gt 0) {
            if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
                try { $process.Kill() } catch { }
                $process.WaitForExit() | Out-Null
                return 124
            }
        } else {
            $process.WaitForExit()
        }
        return $process.ExitCode
    } finally {
        foreach ($key in $saved.Keys) {
            [Environment]::SetEnvironmentVariable($key, $saved[$key], "Process")
        }
    }
}

function Read-RowCapture {
    $lines = @()
    if (Test-Path -LiteralPath $output -PathType Leaf) {
        $lines += @(Get-Content -LiteralPath $output)
    }
    if (Test-Path -LiteralPath $errorOutput -PathType Leaf) {
        $lines += @(Get-Content -LiteralPath $errorOutput)
    }
    return $lines
}

function Test-Lane {
    param([string]$Lanes, [string]$Lane)
    return (",$Lanes," -like "*,$Lane,*")
}

$passed = 0
$failed = 0
$skipped = 0

if (-not $List) {
    Write-Host "demo tests: using zanna binary: $zannaBin"
}

try {
    foreach ($line in Get-Content -LiteralPath $manifestPath) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }
        $columns = $line.Split("`t")
        if ($columns.Count -lt 5) {
            [Console]::Error.WriteLine("MANIFEST ERROR: malformed row: $line")
            ++$failed
            continue
        }
        $rowDemo = $columns[0]
        $rowAction = $columns[1]
        $rowTarget = $columns[2]
        $rowLanes = $columns[3]
        $rowTimeout = [int]$columns[4]
        $rowEnvSpec = if ($columns.Count -ge 6) { $columns[5] } else { "-" }

        # Selection mirrors run_demo_tests.sh: perf needs --perf; fast runs in
        # both modes; full only in the default mode.
        if (Test-Lane $rowLanes "perf") {
            if (-not $Perf) { continue }
        } elseif (Test-Lane $rowLanes "fast") {
            # always selected
        } elseif (Test-Lane $rowLanes "full") {
            if ($Fast) { continue }
        } else {
            continue
        }
        if ($Demo.Count -gt 0 -and ($Demo -notcontains $rowDemo)) {
            continue
        }
        if (Test-Lane $rowLanes "native-arm64-macos") {
            ++$skipped
            Write-Host "SKIP (requires a macOS arm64 host): $rowDemo :: $rowAction $rowTarget"
            continue
        }
        if ($headless -and (Test-Lane $rowLanes "requires_display")) {
            ++$skipped
            Write-Host "SKIP (requires a display (ZANNA_DEMOS_HEADLESS=1)): $rowDemo :: $rowAction $rowTarget"
            continue
        }
        if ($List) {
            Write-Host ("{0}`t{1}`t{2}`t{3}`t{4}`t{5}" -f `
                    $rowDemo, $rowAction, $rowTarget, $rowLanes, $rowTimeout, $rowEnvSpec)
            continue
        }

        $rowEnvironment = @{}
        if ($rowEnvSpec -ne "-" -and -not [string]::IsNullOrWhiteSpace($rowEnvSpec)) {
            foreach ($pair in $rowEnvSpec.Split(",")) {
                $separator = $pair.IndexOf("=")
                if ($separator -lt 1) {
                    [Console]::Error.WriteLine("MANIFEST ERROR: bad env pair '$pair' for $rowDemo")
                    continue
                }
                $rowEnvironment[$pair.Substring(0, $separator)] = $pair.Substring($separator + 1)
            }
        }

        Write-Host "==> $rowDemo :: $rowAction $rowTarget"
        $status = 0
        switch ($rowAction) {
            "check" {
                $checkTarget = if ($rowTarget -eq ".") { Join-Path $root $rowDemo } `
                    else { Join-Path (Join-Path $root $rowDemo) $rowTarget }
                $status = Invoke-RowProcess -FilePath $zannaBin `
                    -NativeArguments @("check", $checkTarget, "--diagnostic-format=json") `
                    -WorkingDirectory $root -TimeoutSeconds $rowTimeout `
                    -RowEnvironment $rowEnvironment
            }
            "run-probe" {
                $status = Invoke-RowProcess -FilePath $zannaBin `
                    -NativeArguments @("run", $rowTarget) `
                    -WorkingDirectory (Join-Path $root $rowDemo) `
                    -TimeoutSeconds $rowTimeout -RowEnvironment $rowEnvironment
            }
            "run-script" {
                $scriptTarget = Join-Path (Join-Path $root $rowDemo) $rowTarget
                if ($scriptTarget.EndsWith(".sh")) {
                    $scriptTarget = $scriptTarget.Substring(0, $scriptTarget.Length - 3) + ".ps1"
                }
                if (-not (Test-Path -LiteralPath $scriptTarget -PathType Leaf)) {
                    [Console]::Error.WriteLine("DEMO TEST FAILED: $rowDemo :: no Windows script $scriptTarget")
                    ++$failed
                    continue
                }
                $rowEnvironment["ZANNA_BIN"] = $zannaBin
                $status = Invoke-RowProcess -FilePath "powershell.exe" `
                    -NativeArguments @("-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", `
                        "-File", $scriptTarget) `
                    -WorkingDirectory $root -TimeoutSeconds $rowTimeout `
                    -RowEnvironment $rowEnvironment
            }
            default {
                [Console]::Error.WriteLine("MANIFEST ERROR: unknown action '$rowAction' for $rowDemo")
                ++$failed
                continue
            }
        }

        $lines = @(Read-RowCapture)
        $lines | ForEach-Object { Write-Host $_ }
        $ok = $false
        if ($status -eq 0) {
            if ($rowAction -eq "run-probe") {
                $ok = $null -ne ($lines | Select-String -SimpleMatch "RESULT: ok" | Select-Object -First 1)
            } else {
                $ok = $true
            }
        }
        if ($ok) {
            ++$passed
        } else {
            [Console]::Error.WriteLine("DEMO TEST FAILED: $rowDemo :: $rowAction $rowTarget (exit $status)")
            ++$failed
        }
    }

    if ($List) {
        exit 0
    }
    Write-Host "zannademos: $passed passed, $failed failed, $skipped skipped"
    if ($failed -ne 0) {
        exit 1
    }
    exit 0
} finally {
    Remove-Item -LiteralPath $output, $errorOutput -Force -ErrorAction SilentlyContinue
}
