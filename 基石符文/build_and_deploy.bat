@echo off
setlocal enabledelayedexpansion

REM ========================================
REM KeystoneRunes Build & Deploy Script
REM ========================================

set "PROJECT_DIR=f:\sts2\基石符文"
set "GAME_DIR=E:\tim_d_laji\sts2\Slay the Spire 2"
set "GAME_EXE=%GAME_DIR%\SlayTheSpire2.exe"
set "GAME_DATA=%GAME_DIR%\data_sts2_windows_x86_64"
set "GODOT=E:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe"
set "DOTNET=C:\Program Files\dotnet\dotnet.exe"
set "MOD_NAME=KeystoneRunes"

cd /d "%PROJECT_DIR%"

REM === Clean previous builds ===
echo [1/6] Cleaning...
rmdir /s /q "%PROJECT_DIR%\src\bin" 2>nul
rmdir /s /q "%PROJECT_DIR%\src\obj" 2>nul
rmdir /s /q "%PROJECT_DIR%\dist" 2>nul
rmdir /s /q "%PROJECT_DIR%\.build" 2>nul

REM === Build C# DLL ===
echo [2/6] Building %MOD_NAME%.dll...
"%DOTNET%" build "%PROJECT_DIR%\src\%MOD_NAME%.csproj" -c Release -p:GameDataDir="%GAME_DATA%"
if errorlevel 1 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b 1
)

REM === Prepare dist ===
echo [3/6] Preparing dist...
mkdir "%PROJECT_DIR%\dist" 2>nul
copy /y "%PROJECT_DIR%\assets\%MOD_NAME%.json" "%PROJECT_DIR%\dist\%MOD_NAME%.json" >nul

REM === Setup import project ===
set "IMPORT_DIR=%PROJECT_DIR%\.build\import_project"
rmdir /s /q "%IMPORT_DIR%" 2>nul
mkdir "%IMPORT_DIR%\%MOD_NAME%" 2>nul
copy /y "%PROJECT_DIR%\tools\project.godot" "%IMPORT_DIR%\project.godot" >nul
xcopy /y /e /i "%PROJECT_DIR%\assets\*" "%IMPORT_DIR%\%MOD_NAME%\" >nul
del "%IMPORT_DIR%\%MOD_NAME%\%MOD_NAME%.json" 2>nul

REM === Godot import ===
echo [4/6] Running Godot asset import...
"%GODOT%" --headless --path "%IMPORT_DIR%" --import
if errorlevel 1 (
    echo.
    echo WARNING: Godot import had errors, continuing...
)

REM === Pack PCK ===
echo [5/6] Creating PCK package...
"%GAME_EXE%" --headless --path "%PROJECT_DIR%\tools" -s res://pack_mod.gd -- "%PROJECT_DIR%\assets\%MOD_NAME%.json" "%PROJECT_DIR%\dist\%MOD_NAME%.pck" "%IMPORT_DIR%"
if errorlevel 1 (
    echo.
    echo WARNING: PCK packing had errors. Check if game supports --headless.
    echo You can still manually deploy the DLL and JSON.
)

REM === Copy DLL ===
set "BUILD_OUT=%PROJECT_DIR%\src\bin\Release\net9.0"
if exist "%BUILD_OUT%\%MOD_NAME%.dll" (
    copy /y "%BUILD_OUT%\%MOD_NAME%.dll" "%PROJECT_DIR%\dist\%MOD_NAME%.dll" >nul
) else (
    echo.
    echo ERROR: %MOD_NAME%.dll not found in %BUILD_OUT%
    pause
    exit /b 1
)

REM === Deploy to mods folder ===
echo [6/6] Deploying to game mods folder...
set "MOD_DIR=%GAME_DIR%\mods\%MOD_NAME%"
rmdir /s /q "%MOD_DIR%" 2>nul
mkdir "%MOD_DIR%" 2>nul
copy /y "%PROJECT_DIR%\dist\%MOD_NAME%.json" "%MOD_DIR%\%MOD_NAME%.json" >nul
if exist "%PROJECT_DIR%\dist\%MOD_NAME%.pck" (
    copy /y "%PROJECT_DIR%\dist\%MOD_NAME%.pck" "%MOD_DIR%\%MOD_NAME%.pck" >nul
)
copy /y "%PROJECT_DIR%\dist\%MOD_NAME%.dll" "%MOD_DIR%\%MOD_NAME%.dll" >nul

echo.
echo ========================================
echo Build and deploy complete!
echo Deployed to: %MOD_DIR%
echo ========================================

endlocal
pause