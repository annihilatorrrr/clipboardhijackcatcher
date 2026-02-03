@echo off
echo ========================================
echo ClipCatcher Service Installer
echo ========================================
echo.

REM Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo.
    echo Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo Looking for clipcatcher.exe...
if not exist "%~dp0clipcatcher.exe" (
    echo ERROR: clipcatcher.exe not found in this folder!
    echo Current folder: %~dp0
    echo.
    dir /b clipcatcher.exe 2>nul
    echo.
    pause
    exit /b 1
)

echo ✅ Found clipcatcher.exe
echo.

REM Stop and remove service if it already exists
sc query ClipCatcher >nul 2>&1
if %errorlevel% equ 0 (
    echo Stopping existing service...
    net stop ClipCatcher >nul 2>&1
    timeout /t 2 /nobreak >nul
    echo Removing existing service...
    sc delete ClipCatcher >nul 2>&1
    timeout /t 2 /nobreak >nul
    echo.
)

echo Installing ClipCatcher service...
echo Full path: %~dp0clipcatcher.exe
sc create ClipCatcher binPath= "%~dp0clipcatcher.exe" start= auto DisplayName= "Clipboard Hijacker Detector"

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Failed to create service!
    echo This might be because:
    echo  1. You're not running as Administrator
    echo  2. A service with this name already exists
    echo  3. The exe path is invalid
    echo.
    pause
    exit /b 1
)

echo ✅ Service created successfully!
echo.

echo Configuring service to restart on failure...
sc failure ClipCatcher reset= 86400 actions= restart/5000/restart/10000/restart/30000

echo.
echo Starting ClipCatcher service...
net start ClipCatcher

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo ✅ SUCCESS! ClipCatcher is now running!
    echo ========================================
    echo.
    echo The service will:
    echo  - Start automatically with Windows
    echo  - Monitor clipboard 24/7
    echo  - Log any hijacking attempts to:
    echo    %~dp0clipboard_hijacker_log.txt
    echo.
    echo To check status: sc query ClipCatcher
    echo To uninstall: run uninstall.bat as admin
    echo.
) else (
    echo.
    echo ⚠️ WARNING: Service created but failed to start!
    echo.
    echo This might be because the exe is not a valid Windows service.
    echo Try checking Windows Event Viewer for error details.
    echo.
    echo To check: eventvwr.msc
    echo Look under: Windows Logs ^> Application
    echo.
)

pause