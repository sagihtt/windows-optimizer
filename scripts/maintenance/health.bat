@echo off
title Manutencao e Saude do Windows

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"

echo ========================================
echo [1/4] Reparando imagem do Windows (DISM)
echo ========================================
DISM /Online /Cleanup-Image /RestoreHealth

echo.
echo ========================================
echo [2/4] Verificando arquivos do sistema (SFC)
echo ========================================
sfc /scannow

echo.
echo ========================================
echo [3/4] Verificando integridade do disco C:
echo ========================================
chkdsk C: /scan

echo.
echo ========================================
echo [4/4] Limpando componentes antigos (WinSxS)
echo ========================================
DISM /Online /Cleanup-Image /StartComponentCleanup

echo.
echo ========================================
echo Manutencao concluida com sucesso!
echo ========================================
pause
