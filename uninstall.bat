@echo off
setlocal

echo ========================================
echo ClipCatcher Service Uninstaller
echo ========================================
echo.

net session >nul 2>&1 || (
    echo Run as Administrator.
    pause
    exit /b 1
)

set BASEDIR=%~dp0
if "%BASEDIR:~-1%"=="\" set BASEDIR=%BASEDIR:~0,-1%

set SERVICE=ClipCatcher
set NSSM=%BASEDIR%\nssm.exe

if not exist "%NSSM%" (
    echo ERROR: nssm.exe not found in current directory
    pause
    exit /b 1
)

sc query %SERVICE% >nul 2>&1
if %errorlevel% neq 0 (
    echo Service not installed.
    pause
    exit /b 0
)

echo Stopping service...
net stop %SERVICE% >nul 2>&1
timeout /t 2 /nobreak >nul

echo Removing service...
"%NSSM%" remove %SERVICE% confirm

echo.
echo ========================================
echo ✅ ClipCatcher service removed
echo ========================================
pause
