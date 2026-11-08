@echo off
title Limpeza de Caches Dev

cd /d "%~dp0"

echo ========================================
echo [1/3] Limpando cache do NPM...
echo ========================================
call npm cache clean --force

echo.
echo ========================================
echo [2/3] Limpando cache do Pip...
echo ========================================
call pip cache purge

echo.
echo ========================================
echo [3/3] Apagando pastas __pycache__ dos projetos (ignorando AppData e venv)...
echo ========================================
powershell -NoProfile -Command "Get-ChildItem -Path $env:USERPROFILE -Directory | Where-Object { $_.Name -notmatch '^(\.|AppData|OneDrive)' } | ForEach-Object { Get-ChildItem -Path $_.FullName -Directory -Recurse -Filter '__pycache__' -ErrorAction SilentlyContinue } | Where-Object { $_.FullName -notmatch '\\(node_modules|\.venv|venv|site-packages)\\' } | ForEach-Object { Write-Host ('Removendo: ' + $_.FullName); Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }"

echo.
echo ========================================
echo Caches de desenvolvimento limpos!
echo ========================================
pause
