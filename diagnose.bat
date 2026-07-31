@echo off
cd /d "%~dp0"
title amfetamin teshis
echo amfetamin teshis araci baslatiliyor...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0diagnose.ps1\"\"' -Wait"
echo.
echo Bitti. Masaustunde amfetamin-diagnose.txt dosyasina bak.
pause
