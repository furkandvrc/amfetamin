@echo off
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" (
    echo PowerShell bulunamadi.
    pause
    exit /b 1
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Amfetamin.ps1"
if errorlevel 1 (
    echo amfetamin baslatilamadi.
    pause
)
