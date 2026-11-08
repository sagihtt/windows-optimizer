@echo off
title Limpeza de Arquivos Temporarios

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"

echo ========================================
echo [1/4] Limpando Temp do Usuario...
echo ========================================
del /s /f /q "%temp%\*.*" >nul 2>&1
for /d %%p in ("%temp%\*") do rmdir /s /q "%%p" >nul 2>&1

echo.
echo ========================================
echo [2/4] Limpando Temp do Windows...
echo ========================================
del /s /f /q "C:\Windows\Temp\*.*" >nul 2>&1
for /d %%p in ("C:\Windows\Temp\*") do rmdir /s /q "%%p" >nul 2>&1

echo.
echo ========================================
echo [3/4] Limpando Cache de Downloads do Windows Update...
echo ========================================
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
del /s /f /q "C:\Windows\SoftwareDistribution\Download\*.*" >nul 2>&1
for /d %%p in ("C:\Windows\SoftwareDistribution\Download\*") do rmdir /s /q "%%p" >nul 2>&1

echo.
echo ========================================
echo [4/4] Esvaziando Lixeira...
echo ========================================
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"

echo.
echo ========================================
echo Limpeza de temporarios concluida!
echo (Prefetch mantido intacto para preservar o cache de abertura rapida)
echo ========================================
pause
