#===----------------------------------------------------------------------===#
#
# Part of the Zanna project, under the GNU GPL v3.
# See LICENSE for license information.
#
#===----------------------------------------------------------------------===#
#
# File: scripts/build_demos.ps1
# Purpose: Build every demo in this repository by delegating to the Zanna
#          repo's Windows demo builder with this repo as the demo root.
# Key invariants:
#   - No build logic is duplicated here; the parent builder owns it.
#   - Requires this repository to be cloned inside a Zanna checkout (the
#     documented nested layout) so ..\scripts\build_demos_win.ps1 exists.
# Ownership/Lifetime: Build outputs land in bin\ (gitignored).
# Cross-platform touchpoints: build_demos.sh is the POSIX entry point.
# Links: demos.list, ..\scripts\build_demos_win.ps1
#
#===----------------------------------------------------------------------===#

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = [IO.Path]::GetFullPath((Join-Path $scriptDir ".."))
$parentBuilder = [IO.Path]::GetFullPath((Join-Path $root "..\scripts\build_demos_win.ps1"))

if (-not (Test-Path -LiteralPath $parentBuilder -PathType Leaf)) {
    [Console]::Error.WriteLine("error: building demos requires the Zanna repo checked out as the parent of this clone")
    [Console]::Error.WriteLine("expected builder at: $parentBuilder")
    exit 1
}

$env:ZANNA_DEMO_MANIFEST = Join-Path $root "demos.list"
$env:ZANNA_DEMO_ROOT = $root
$env:ZANNA_DEMO_BIN_DIR = Join-Path $root "bin"

& $parentBuilder @args
exit $LASTEXITCODE
