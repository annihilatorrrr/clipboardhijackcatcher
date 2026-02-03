@echo off
echo ========================================
echo ClipCatcher Service Uninstaller
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

echo Stopping ClipCatcher service...
net stop ClipCatcher 2>nul

if %errorlevel% equ 0 (
    echo ✅ Service stopped
) else (
    echo ⚠️  Service was not running
)

timeout /t 2 /nobreak >nul

echo Removing ClipCatcher service...
sc delete ClipCatcher

if %errorlevel% equ 0 (
    echo ✅ Service removed successfully
    echo.
    echo The service has been uninstalled.
    echo You can manually delete clipcatcher.exe if desired.
) else (
    echo ⚠️  Service may not have been installed
)

echo.
pause