@echo off
powershell.exe -NoProfile -STA -File "%~dp0src\FlashScan.ps1"
if errorlevel 1 pause
