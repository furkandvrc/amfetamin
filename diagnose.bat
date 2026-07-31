@echo off
cd /d "%~dp0"
title amfetamin teshis
echo.
echo amfetamin teshis araci
echo Dosya bu klasore yazilacak: %~dp0amfetamin-diagnose.txt
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0diagnose.ps1"
echo.
if exist "%~dp0amfetamin-diagnose.txt" (
    echo BASARILI: %~dp0amfetamin-diagnose.txt
) else (
    echo UYARI: Dosya olusmadi. TEMP klasorune bak: %TEMP%\amfetamin-diagnose.txt
)
echo.
pause
