@echo off
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0launch.ps1" %*
exit /b %errorlevel%
