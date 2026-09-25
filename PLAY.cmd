@echo off
setlocal EnableExtensions
pushd "%~dp0" || (
    echo Could not open the game folder.
    pause
    exit /b 1
)
set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
    set "GODOT="
    for %%E in (Godot_v4.7.2-stable_win64.exe godot.exe godot) do (
        if not defined GODOT for /f "delims=" %%P in ('where %%E 2^>nul') do if not defined GODOT set "GODOT=%%P"
    )
)
if not exist "%GODOT%" (
    echo Godot 4.7.2 was not found.
    echo Add Godot to PATH or open project.godot in Godot and press F5.
    popd
    pause
    exit /b 1
)
start /wait "" "%GODOT%" --headless --editor --path . --import --quit
if errorlevel 1 (
    echo Asset import failed. Open project.godot in Godot to see the error.
    popd
    pause
    exit /b 1
)
if /I "%~1"=="--verify" (
    echo Asset import succeeded.
    popd
    exit /b 0
)
start "" "%GODOT%" --path .
popd
