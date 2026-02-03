@echo off
setlocal enabledelayedexpansion

echo ========================================
echo ClipCatcher Service Installer
echo ========================================
echo.

REM --- Admin check ---
net session >nul 2>&1 || (
    echo ERROR: Run as Administrator.
    pause
    exit /b 1
)

REM --- Resolve current directory safely ---
set BASEDIR=%~dp0
if "%BASEDIR:~-1%"=="\" set BASEDIR=%BASEDIR:~0,-1%

set SERVICE=ClipCatcher
set EXE=%BASEDIR%\clipcatcher.exe
set NSSM=%BASEDIR%\nssm.exe

echo Using directory:
echo   %BASEDIR%
echo.

REM --- Validate files ---
if not exist "%EXE%" (
    echo ERROR: clipcatcher.exe not found in current directory
    pause
    exit /b 1
)

if not exist "%NSSM%" (
    echo ERROR: nssm.exe not found in current directory
    pause
    exit /b 1
)

REM --- Remove existing service ---
sc query %SERVICE% >nul 2>&1 && (
    echo Removing existing service...
    net stop %SERVICE% >nul 2>&1
    "%NSSM%" remove %SERVICE% confirm
)

REM --- Install service ---
echo Installing service...
"%NSSM%" install %SERVICE% "%EXE%"

REM --- Configure service ---
"%NSSM%" set %SERVICE% DisplayName "Clipboard Hijacker Detector"
"%NSSM%" set %SERVICE% Start SERVICE_AUTO_START
"%NSSM%" set %SERVICE% AppDirectory "%BASEDIR%"
"%NSSM%" set %SERVICE% AppNoConsole 1
"%NSSM%" set %SERVICE% AppRestartDelay 5000

REM --- Start service ---
net start %SERVICE%

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo ✅ ClipCatcher is LIVE
    echo ========================================
) else (
    echo.
    echo ⚠️ Service installed but failed to start
    echo Check Event Viewer or NSSM logs
)

pause
