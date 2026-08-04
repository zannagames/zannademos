@rem ===----------------------------------------------------------------------===
@rem
@rem Part of the Zanna project, under the GNU GPL v3.
@rem See LICENSE for license information.
@rem
@rem ===----------------------------------------------------------------------===
@rem
@rem File: scripts/run_demo_tests.cmd
@rem Purpose: Preserve a cmd.exe demo-test entry point as a thin forwarding
@rem          shim to the canonical PowerShell implementation.
@rem Key invariants:
@rem   - No runner logic is duplicated here.
@rem   - Every caller argument and the exact PowerShell exit status are forwarded.
@rem Ownership/Lifetime: The PowerShell implementation owns all temporary files.
@rem Links: scripts/run_demo_tests.ps1
@rem
@rem ===----------------------------------------------------------------------===
@echo off
setlocal
set "ZANNA_DEMO_POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%ZANNA_DEMO_POWERSHELL%" (
    echo Error: Windows PowerShell was not found at "%ZANNA_DEMO_POWERSHELL%". 1>&2
    exit /b 1
)
"%ZANNA_DEMO_POWERSHELL%" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0run_demo_tests.ps1" %*
set "ZANNA_DEMO_STATUS=%ERRORLEVEL%"
endlocal & exit /b %ZANNA_DEMO_STATUS%
