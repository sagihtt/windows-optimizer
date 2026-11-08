#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Aplica todas as otimizações seguras de Kernel, Memória, GPU (MSI Mode + HAGS), MMCSS (Jogos),
    Energia (USB + PCIe ASPM + Fast Startup) e Rede (TCPNoDelay) com detecção automática de hardware.
#>

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   WINDOWS MASTER OPTIMIZER - OTIMIZACAO 1-CLICK          " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Memória RAM e Kernel Memory Management
$os = Get-CimInstance Win32_OperatingSystem
$totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB)
$memPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

Set-ItemProperty -Path $memPath -Name "SecondLevelDataCache" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $memPath -Name "PagedPoolSize" -Value 0 -Type DWord -Force
Remove-ItemProperty -Path $memPath -Name "IoPageLockLimit" -ErrorAction SilentlyContinue

if ($totalGB -ge 14) {
    Set-ItemProperty -Path $memPath -Name "LargeSystemCache" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $memPath -Name "DisablePagingExecutive" -Value 1 -Type DWord -Force
    Write-Host "[1/6] Gerenciador de Memoria ajustado para $totalGB GB (LargeSystemCache=1, DisablePagingExecutive=1, travas legadas removidas)." -ForegroundColor Green
} else {
    Set-ItemProperty -Path $memPath -Name "DisablePagingExecutive" -Value 1 -Type DWord -Force
    Write-Host "[1/6] Gerenciador de Memoria limpo para $totalGB GB (travas legadas removidas)." -ForegroundColor Green
}

# 2. Inicialização Rápida (Preservar estado ACPI CPPC do Turbo Boost) e Win32PrioritySeparation
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "GlobalTimerResolutionRequests" -Value 1 -Type DWord -Force
Write-Host "[2/6] Kernel: Win32PrioritySeparation=38 (0x26), HiberbootEnabled=1 e GlobalTimerResolutionRequests=1." -ForegroundColor Green

# 3. Agendador Multimídia (MMCSS) e Limite de Rede para Jogos
$mmcssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
$gamesPath = "$mmcssPath\Tasks\Games"
Set-ItemProperty -Path $mmcssPath -Name "SystemResponsiveness" -Value 10 -Type DWord -Force
Set-ItemProperty -Path $mmcssPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force
if (-not (Test-Path $gamesPath)) { New-Item -Path $gamesPath -Force | Out-Null }
Set-ItemProperty -Path $gamesPath -Name "GPU Priority" -Value 8 -Type DWord -Force
Set-ItemProperty -Path $gamesPath -Name "Priority" -Value 6 -Type DWord -Force
Set-ItemProperty -Path $gamesPath -Name "Scheduling Category" -Value "High" -Force
Set-ItemProperty -Path $gamesPath -Name "SFIO Priority" -Value "High" -Force
Write-Host "[3/6] MMCSS: SystemResponsiveness=10, NetworkThrottlingIndex=0xFFFFFFFF e Tasks\Games=High." -ForegroundColor Green

# 4. GPU: HAGS, GameDVR Off e MSI Mode High Priority na GPU dedicada
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

$gpus = Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPClass -eq 'Display' -and $_.Name -match 'NVIDIA|Radeon|RTX|GTX|Arc' }
foreach ($gpu in $gpus) {
    $msiPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($gpu.DeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
    $affPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($gpu.DeviceID)\Device Parameters\Interrupt Management\Affinity Policy"
    if (-not (Test-Path $msiPath)) { New-Item -Path $msiPath -Force | Out-Null }
    if (-not (Test-Path $affPath)) { New-Item -Path $affPath -Force | Out-Null }
    Set-ItemProperty -Path $msiPath -Name "MSISupported" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $affPath -Name "DevicePriority" -Value 3 -Type DWord -Force
    Write-Host "[4/6] GPU ($($gpu.Name)): HAGS=Ativo, MSI Mode=1 e DevicePriority=3 (High)." -ForegroundColor Green
}

# 5. Energia (Desativar Suspensão Seletiva USB e PCIe ASPM na tomada + SSD TRIM)
powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT
fsutil behavior set disablelastaccess 1 | Out-Null
fsutil behavior set disabledeletenotify 0 | Out-Null
Write-Host "[5/6] Energia e SSD: PCIe ASPM Off (AC), Suspensao USB Off (AC), TRIM ativo e LastAccess desativado." -ForegroundColor Green

# 6. Rede (Parâmetros Globais + TCPNoDelay inteligente por tipo de mídia: Cabo vs Wi-Fi)
netsh int tcp set global autotuninglevel=normal | Out-Null
netsh int tcp set global rss=enabled | Out-Null
netsh int tcp set global rsc=enabled | Out-Null
netsh int tcp set global ecncapability=default | Out-Null

$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
foreach ($a in $adapters) {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($a.InterfaceGuid)"
    if (Test-Path $regPath) {
        Set-ItemProperty -Path $regPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
        if ($a.PhysicalMediaType -match "802\.3|Ethernet" -and $a.Name -notmatch "Wi-Fi|Wireless") {
            Set-ItemProperty -Path $regPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
            Write-Host "[6/6] Rede Cabo ($($a.Name)): TCPNoDelay=1 e TcpAckFrequency=1 aplicados." -ForegroundColor Green
        } else {
            Write-Host "[6/6] Rede Wi-Fi ($($a.Name)): TCPNoDelay=1 aplicado (TcpAckFrequency mantido no padrao para evitar colisao half-duplex)." -ForegroundColor Green
        }
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "Otimizacao concluida! Use a opcao REINICIAR do Windows" -ForegroundColor Yellow
Write-Host "(nao use Desligar) para recarregar o Registro do zero." -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
