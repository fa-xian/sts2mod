@echo off
setlocal enabledelayedexpansion

set "DOTNET=C:\Program Files\dotnet\dotnet.exe"
set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%..") do set "ROOT=%%~fi"
set "FILE_STEM=HextechRunes"
set "MANIFEST_SRC=%ROOT%\assets\%FILE_STEM%.json"
set "GAME_DIR=E:\tim_d_laji\sts2\Slay the Spire 2"
set "GAME_BIN=%GAME_DIR%\SlayTheSpire2.exe"
set "MOD_DIR=%GAME_DIR%\mods\%FILE_STEM%"
set "BUILD_OUT=%ROOT%\src\bin\Release\net9.0"
set "PROJECT_PATH=%ROOT%\src\%FILE_STEM%.csproj"
set "IMPORT_PROJECT=%ROOT%\.build\import_project"
set "GODOT_EDITOR=E:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe"
set "REFS_103=%ROOT%\versioned-dll-backups\0.103.2\game-refs"
set "REFS_104=%ROOT%\versioned-dll-backups\0.104.0\game-refs"
set "REFS_105=%ROOT%\versioned-dll-backups\0.105.1\game-refs"
set "GAME_RELEASE_INFO=%GAME_DIR%\release_info.json"
set "DEFAULT_STS2_TARGET=0.103.2"

if not defined HEXTECH_DEPLOY set "HEXTECH_DEPLOY=1"

call :check_version_warning

echo Cleaning previous build artifacts...
if exist "%ROOT%\src\bin" rmdir /s /q "%ROOT%\src\bin"
if exist "%ROOT%\src\obj" rmdir /s /q "%ROOT%\src\obj"
if exist "%ROOT%\dist" rmdir /s /q "%ROOT%\dist"
if exist "%ROOT%\.build" rmdir /s /q "%ROOT%\.build"

echo Running Python content validation...
"F:\qiguai_app\python_14\python.exe" "%ROOT%\tools\validate_hextech_content.py"
if %errorlevel% neq 0 (
    echo Python content validation failed
    pause
    exit /b %errorlevel%
)

set "CURRENT_GAME_VERSION="
if exist "%GAME_RELEASE_INFO%" (
    for /f "tokens=*" %%a in ('powershell -Command "(Get-Content '%GAME_RELEASE_INFO%' -Raw | ConvertFrom-Json).version -replace '^v',''" 2^>nul') do set "CURRENT_GAME_VERSION=%%a"
)

if not defined HEXTECH_STS2_TARGET set "HEXTECH_STS2_TARGET=%DEFAULT_STS2_TARGET%"

set "TARGET_REFS="
for /f "tokens=1-3 delims=." %%a in ("%HEXTECH_STS2_TARGET%") do (
    set "STS2_MAJOR=%%a"
    set "STS2_MINOR=%%b"
)

if "!HEXTECH_STS2_TARGET:~0,5!"=="0.105" (
    set "HEXTECH_STS2_TARGET=0.105.1"
    set "TARGET_REFS=%REFS_105%"
) else if "!HEXTECH_STS2_TARGET:~0,5!"=="0.104" (
    set "HEXTECH_STS2_TARGET=0.104.0"
    set "TARGET_REFS=%REFS_104%"
) else if "!HEXTECH_STS2_TARGET:~0,5!"=="0.103" (
    set "HEXTECH_STS2_TARGET=0.103.2"
    set "TARGET_REFS=%REFS_103%"
) else (
    echo Unsupported or unknown STS2 version '%HEXTECH_STS2_TARGET%'; using live game references without compatibility defines.
    set "TARGET_REFS=%GAME_DIR%\data"
)

if not exist "!TARGET_REFS!\sts2.dll" (
    echo Versioned backups not found at !TARGET_REFS!, falling back to game data directory...
    set "TARGET_REFS=%GAME_DIR%\data_sts2_windows_x86_64"
)

if "%HEXTECH_DEPLOY%" neq "0" (
    call :check_version_mismatch
)

for %%d in (sts2.dll GodotSharp.dll 0Harmony.dll) do (
    if not exist "%TARGET_REFS%\%%d" (
        echo Missing required reference for STS2 %HEXTECH_STS2_TARGET%: %TARGET_REFS%\%%d
        echo Back up the matching game refs before building.
        pause
        exit /b 1
    )
)

echo Building %FILE_STEM% for STS2 %HEXTECH_STS2_TARGET% using %TARGET_REFS%
"%DOTNET%" build "%PROJECT_PATH%" -c Release ^
  -p:HextechSts2Target="%HEXTECH_STS2_TARGET%" ^
  -p:GameDataDir="%TARGET_REFS%"
if %errorlevel% neq 0 (
    echo dotnet build failed
    pause
    exit /b %errorlevel%
)

if not exist "%ROOT%\dist" mkdir "%ROOT%\dist"
if not exist "%IMPORT_PROJECT%\%FILE_STEM%" mkdir "%IMPORT_PROJECT%\%FILE_STEM%"
if "%HEXTECH_DEPLOY%" neq "0" (
    if exist "%MOD_DIR%" rmdir /s /q "%MOD_DIR%"
    mkdir "%MOD_DIR%"
)

copy /y "%ROOT%\tools\project.godot" "%IMPORT_PROJECT%\project.godot" >nul

robocopy "%ROOT%\assets" "%IMPORT_PROJECT%\%FILE_STEM%" /E /XF "%FILE_STEM%.json" >nul
if %errorlevel% geq 8 (
    echo Error copying assets
    pause
    exit /b 1
)

echo Running Godot import...
"%GODOT_EDITOR%" --headless --path "%IMPORT_PROJECT%" --import
if %errorlevel% neq 0 (
    echo Godot import failed
    pause
    exit /b %errorlevel%
)

copy /y "%MANIFEST_SRC%" "%ROOT%\dist\%FILE_STEM%.json" >nul
if "%HEXTECH_DEPLOY%" neq "0" (
    copy /y "%ROOT%\dist\%FILE_STEM%.json" "%MOD_DIR%\%FILE_STEM%.json" >nul
)

echo Packing PCK...
"%GAME_BIN%" --headless --path "%ROOT%\tools" -s res://pack_mod.gd -- "%MANIFEST_SRC%" "%ROOT%\dist\%FILE_STEM%.pck" "%IMPORT_PROJECT%"
if %errorlevel% neq 0 (
    echo PCK packing failed
    pause
    exit /b %errorlevel%
)

if "%HEXTECH_DEPLOY%" neq "0" (
    copy /y "%ROOT%\dist\%FILE_STEM%.pck" "%MOD_DIR%\%FILE_STEM%.pck" >nul
)

for %%f in ("%BUILD_OUT%\*.dll") do (
    set "DLL_NAME=%%~nxf"
    if "!DLL_NAME!"=="sts2.dll" (
        rem skip
    ) else if "!DLL_NAME!"=="GodotSharp.dll" (
        rem skip
    ) else (
        copy /y "%%f" "%ROOT%\dist\!DLL_NAME!" >nul
        if "%HEXTECH_DEPLOY%" neq "0" (
            copy /y "%%f" "%MOD_DIR%\!DLL_NAME!" >nul
        )
    )
)

if "%HEXTECH_DEPLOY%" neq "0" (
    echo Deployed to %MOD_DIR%
) else (
    echo Built package artifacts in %ROOT%\dist without deploying to the installed game.
)

pause
exit /b 0

:check_version_warning
    set "GAME_GODOT_VERSION="
    for /f "tokens=*" %%a in ('"%GAME_BIN%" --version 2^>nul') do (
        if not defined GAME_GODOT_VERSION set "GAME_GODOT_VERSION=%%a"
    )
    set "IMPORT_GODOT_VERSION="
    for /f "tokens=*" %%a in ('"%GODOT_EDITOR%" --version 2^>nul') do (
        if not defined IMPORT_GODOT_VERSION set "IMPORT_GODOT_VERSION=%%a"
    )

    if defined GAME_GODOT_VERSION if defined IMPORT_GODOT_VERSION (
        set "GAME_MAJOR_MINOR="
        set "IMPORT_MAJOR_MINOR="
        for /f "tokens=1,2 delims=." %%a in ("!GAME_GODOT_VERSION!") do set "GAME_MAJOR_MINOR=%%a.%%b"
        for /f "tokens=1,2 delims=." %%a in ("!IMPORT_GODOT_VERSION!") do set "IMPORT_MAJOR_MINOR=%%a.%%b"
        if not "!GAME_MAJOR_MINOR!"=="!IMPORT_MAJOR_MINOR!" (
            echo Warning: asset import Godot version ^(!IMPORT_GODOT_VERSION!^) differs from game runtime ^(!GAME_GODOT_VERSION!^).
            echo Set GODOT_EDITOR to a matching 4.5.x editor if mobile/runtime texture compatibility regresses.
        )
    )
    exit /b

:check_version_mismatch
    if not defined CURRENT_GAME_VERSION exit /b

    set "CUR_MAJOR_MINOR="
    for /f "tokens=1,2 delims=." %%a in ("!CURRENT_GAME_VERSION!") do set "CUR_MAJOR_MINOR=%%a.%%b"

    set "TARGET_MAJOR_MINOR="
    for /f "tokens=1,2 delims=." %%a in ("!HEXTECH_STS2_TARGET!") do set "TARGET_MAJOR_MINOR=%%a.%%b"

    if "!TARGET_MAJOR_MINOR!"=="!CUR_MAJOR_MINOR!" exit /b

    if defined HEXTECH_ALLOW_VERSION_MISMATCH (
        if "!HEXTECH_ALLOW_VERSION_MISMATCH!"=="1" (
            echo Warning: deploying STS2 !HEXTECH_STS2_TARGET! build into installed STS2 !CURRENT_GAME_VERSION! because HEXTECH_ALLOW_VERSION_MISMATCH=1.
            exit /b
        )
    )

    echo Refusing to deploy %FILE_STEM% built for STS2 %HEXTECH_STS2_TARGET% into installed STS2 %CURRENT_GAME_VERSION%.
    echo Switch the installed game to the matching branch, set HEXTECH_DEPLOY=0 to package only, or set HEXTECH_ALLOW_VERSION_MISMATCH=1 if you are intentionally deploying against a different installed version.
    pause
    exit /b 1
