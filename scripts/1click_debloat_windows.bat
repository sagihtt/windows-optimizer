@echo off
title 1-Click Windows Debloat (OneDrive, Copilot, Recall, Bloatware & Telemetria)
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0debloat_windows_1click.ps1"
pause
