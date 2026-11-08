@echo off
title Reparar Conexao e DNS

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"

echo ========================================
echo [1/5] Limpando cache de DNS...
echo ========================================
ipconfig /flushdns

echo.
echo ========================================
echo [2/5] Resetando pilha TCP/IP e Winsock...
echo ========================================
netsh int ip reset >nul 2>&1
netsh winsock reset >nul 2>&1

echo.
echo ========================================
echo [3/5] Renovando conexao IP...
echo ========================================
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1

echo.
echo ========================================
echo [4/5] Garantindo parametros globais TCP...
echo ========================================
netsh int tcp set global autotuninglevel=normal >nul 2>&1
netsh int tcp set global rss=enabled >nul 2>&1
netsh int tcp set global rsc=enabled >nul 2>&1
netsh int tcp set global ecncapability=default >nul 2>&1

echo.
echo ========================================
echo [5/5] Reaplicando TCPNoDelay (No Nagle) na placa ativa...
echo ========================================
powershell -NoProfile -Command "$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }; foreach ($a in $adapters) { $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\' + $a.InterfaceGuid; if (Test-Path $regPath) { Set-ItemProperty -Path $regPath -Name 'TCPNoDelay' -Value 1 -Type DWord -Force; if ($a.PhysicalMediaType -match '802\.3|Ethernet' -and $a.Name -notmatch 'Wi-Fi|Wireless') { Set-ItemProperty -Path $regPath -Name 'TcpAckFrequency' -Value 1 -Type DWord -Force; Write-Host ('TCPNoDelay=1 e TcpAckFrequency=1 aplicados em (Cabo): ' + $a.Name) } else { Remove-ItemProperty -Path $regPath -Name 'TcpAckFrequency' -ErrorAction SilentlyContinue; Write-Host ('TCPNoDelay=1 aplicado em (Wi-Fi): ' + $a.Name) } } }"

echo.
echo ========================================
echo Rede reparada e otimizada!
echo OBS: Como a pilha TCP/Winsock foi resetada, reinicie o PC se notar instabilidade.
echo ========================================
pause
