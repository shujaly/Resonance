@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "MODE=play"
if /I "%~1"=="--verify" set "MODE=verify"
if /I "%~1"=="--check" set "MODE=check"
if not "%~1"=="" if "%MODE%"=="play" (
    echo Usage: PLAY.cmd [--check ^| --verify]
    exit /b 1
)
if not exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" (
    echo Windows PowerShell is missing. Repair Windows PowerShell through Windows settings.
    echo No software was installed.
    if "%MODE%"=="play" pause
    exit /b 1
)
if not exist "%~dp0tools\launch.ps1" (
    echo Missing tools\launch.ps1. Extract the complete game folder before playing.
    if "%MODE%"=="play" pause
    exit /b 1
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch.ps1" -Mode "%MODE%"
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" if "%MODE%"=="play" pause
exit /b %RESULT%
