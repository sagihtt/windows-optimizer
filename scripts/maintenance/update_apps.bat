@echo off
title Atualizar Programas (Winget)

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"

echo ========================================
echo Atualizando programas instalados...
echo ========================================
winget upgrade --all --accept-package-agreements --accept-source-agreements

echo.
echo ========================================
echo Atualizacoes concluidas!
echo ========================================
pause
