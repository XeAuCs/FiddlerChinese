@echo off
setlocal
title Fiddler Chinese UI Installer
echo Please close Fiddler before installing.
echo.
if "%~1"=="" (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
) else (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" -FiddlerPath "%~1"
)
if errorlevel 1 goto failed
echo.
echo Installation completed. You can now open Fiddler.
pause
exit /b 0
:failed
echo.
echo Installation failed. See the message above.
echo If Fiddler is running, close it and run this installer again.
pause
exit /b 1
