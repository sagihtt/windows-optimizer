#Requires -Version 5.1
<#
.SYNOPSIS
    Radiografia completa e somente-leitura do Windows 10/11 para diagnóstico de performance e latência.
#>

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   WINDOWS MASTER OPTIMIZER - AUDITORIA DE TELEMETRIA     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

Write-Host "`n[1/7] BOOT, CPU & TURBO BOOST (ACPI CPPC)" -ForegroundColor Yellow
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
Write-Host "CPU: $($cpu.Name) | Base: $($cpu.MaxClockSpeed) MHz | Cores: $($cpu.NumberOfCores)C/$($cpu.NumberOfLogicalProcessors)T"

Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-Boot'; Id=27} -MaxEvents 2 -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host "Boot Event ($($_.TimeCreated)): $($_.Message.Trim())" }

Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-Processor-Power'; Id=55} -MaxEvents 8 -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'processador 0 no grupo 0|processor 0 in group 0' } |
    Select-Object -First 1 |
    ForEach-Object {
        $maxPerf = if ($_.Message -match 'máximo:\s*(\d+)|maximum performance percentage:\s*(\d+)') { $Matches[1] + $Matches[2] } else { "?" }
        Write-Host "ACPI CPPC Max Performance (Core 0): $maxPerf% ($($_.TimeCreated))"
    }

$hiber = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -ErrorAction SilentlyContinue).HiberbootEnabled
Write-Host "Fast Startup (HiberbootEnabled): $hiber"

Write-Host "`n[2/7] MEMORIA RAM, PAGEFILE & KERNEL MEMORY MANAGEMENT" -ForegroundColor Yellow
$os = Get-CimInstance Win32_OperatingSystem
$totalMB = [math]::Round($os.TotalVisibleMemorySize / 1024)
$freeMB  = [math]::Round($os.FreePhysicalMemory / 1024)
Write-Host "RAM Total: $totalMB MB | Disponivel: $freeMB MB"

Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel, DeviceLocator, Manufacturer, PartNumber, @{N='GB';E={[math]::Round($_.Capacity/1GB)}}, ConfiguredClockSpeed | Format-Table -AutoSize

Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage | Format-Table -AutoSize

Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -ErrorAction SilentlyContinue |
    Select-Object LargeSystemCache, DisablePagingExecutive, SecondLevelDataCache, PagedPoolSize, IoPageLockLimit | Format-List

Write-Host "`n[3/7] TIMER RESOLUTION REAL (NTDLL) & ISLC" -ForegroundColor Yellow
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinTimer {
    [DllImport("ntdll.dll", SetLastError=true)]
    public static extern int NtQueryTimerResolution(out uint MinimumResolution, out uint MaximumResolution, out uint CurrentResolution);
}
"@ -ErrorAction SilentlyContinue
$min = 0; $max = 0; $cur = 0
[WinTimer]::NtQueryTimerResolution([ref]$min, [ref]$max, [ref]$cur) | Out-Null
Write-Host "Current Timer Resolution: $($cur / 10000.0) ms (Default: $($min / 10000.0) ms, Max Supported: $($max / 10000.0) ms)"

$gtr = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "GlobalTimerResolutionRequests" -ErrorAction SilentlyContinue).GlobalTimerResolutionRequests
Write-Host "GlobalTimerResolutionRequests (Win11 Kernel): $gtr"

$islcProc = Get-Process -Name "Intelligent standby list cleaner ISLC" -ErrorAction SilentlyContinue
Write-Host "ISLC em execucao: $(if ($islcProc) { 'SIM (PID ' + $islcProc.Id + ')' } else { 'NAO' })"
$tsProc = Get-Process -Name "ThrottleStop*" -ErrorAction SilentlyContinue
Write-Host "ThrottleStop em execucao: $(if ($tsProc) { 'SIM (PID ' + $tsProc.Id + ')' } else { 'NAO' })"

Write-Host "`n[4/7] GPU, HAGS, GAMEDVR, MMCSS & INTERRUPCOES MSI" -ForegroundColor Yellow
$hags = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction SilentlyContinue).HwSchMode
$gdvr = (Get-ItemProperty "HKCU:\System\GameConfigStore" -ErrorAction SilentlyContinue).GameDVR_Enabled
$prioSep = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ErrorAction SilentlyContinue).Win32PrioritySeparation
$mmcss = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue
$games = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -ErrorAction SilentlyContinue
Write-Host "HAGS (HwSchMode): $hags | GameDVR_Enabled: $gdvr | Win32PrioritySeparation: $prioSep"
Write-Host "MMCSS SystemResponsiveness: $($mmcss.SystemResponsiveness) | NetworkThrottlingIndex: $($mmcss.NetworkThrottlingIndex)"
Write-Host "MMCSS Games -> Priority: $($games.Priority) | GPU Priority: $($games.'GPU Priority') | Scheduling: $($games.'Scheduling Category') | SFIO: $($games.'SFIO Priority')"

Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPClass -in @('Display', 'SCSIAdapter', 'Net') } | ForEach-Object {
    $id = $_.DeviceID
    $msi = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" -ErrorAction SilentlyContinue).MSISupported
    $prio = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management\Affinity Policy" -ErrorAction SilentlyContinue).DevicePriority
    if ($null -ne $msi) {
        [PSCustomObject]@{ Device = $_.Name; Class = $_.PNPClass; MSISupported = $msi; DevicePriority = $prio }
    }
} | Format-Table -AutoSize

Write-Host "`n[5/7] PLANO DE ENERGIA, PCIE ASPM & SUSPENSAO SELETIVA USB" -ForegroundColor Yellow
powercfg /getactivescheme
powercfg /query SCHEME_CURRENT SUB_PCIEXPRESS ee12f906-d277-404b-b6da-e5fa1a576df5 | Select-String "Correntes|Power Setting Index"
powercfg /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 | Select-String "Correntes|Power Setting Index"

Write-Host "`n[6/7] REDE TCP/IP & TCPNODELAY (ALGORITMO DE NAGLE)" -ForegroundColor Yellow
Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
    $reg = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($_.InterfaceGuid)"
    $p = Get-ItemProperty $reg -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Adapter = $_.Name
        Media = $_.MediaType
        LinkSpeed = $_.LinkSpeed
        Guid = $_.InterfaceGuid
        TCPNoDelay = $p.TCPNoDelay
        TcpAckFrequency = $p.TcpAckFrequency
    }
} | Format-Table -AutoSize

Write-Host "`n[7/7] ARMAZENAMENTO (SSD/TRIM) & INICIALIZACAO ATIVA" -ForegroundColor Yellow
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -ErrorAction SilentlyContinue |
    Select-Object NtfsDisableLastAccessUpdate, DisableDeleteNotification | Format-List

$runPaths = @(
    @{ Run="HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; App="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" },
    @{ Run="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; App="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" },
    @{ Run="HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"; App="HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" }
)
$(foreach ($rp in $runPaths) {
    if (Test-Path $rp.Run) {
        $runProps = Get-ItemProperty $rp.Run
        $appProps = if (Test-Path $rp.App) { Get-ItemProperty $rp.App } else { $null }
        $runProps.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
            $name = $_.Name
            $status = "Enabled (Default)"
            if ($appProps -and $appProps.PSObject.Properties[$name]) {
                $b = $appProps.PSObject.Properties[$name].Value[0]
                $status = if ($b -in @(2, 6)) { "Enabled" } else { "Disabled ($b)" }
            }
            if ($status -match "^Enabled") {
                [PSCustomObject]@{ StartupItem = $name; Status = $status; Command = $_.Value }
            }
        }
    }
}) | Format-Table -AutoSize

Write-Host "`n[8/8] BLOATWARE, ONEDRIVE, COPILOT, RECALL & SERVICOS DE TELEMETRIA" -ForegroundColor Yellow
$odInstalled = (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe") -or (Test-Path "C:\Program Files\Microsoft OneDrive\OneDrive.exe")
$odLocked    = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -ErrorAction SilentlyContinue).DisableFileSyncNGSC
$copilotOff  = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -ErrorAction SilentlyContinue).TurnOffWindowsCopilot
$recallOff   = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -ErrorAction SilentlyContinue).DisableAIDataAnalysis
$widgetsOff  = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ErrorAction SilentlyContinue).TaskbarDa
$bingOff     = (Get-ItemProperty "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -ErrorAction SilentlyContinue).DisableSearchBoxSuggestions
$telemPol    = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ErrorAction SilentlyContinue).AllowTelemetry

Write-Host "OneDrive Instalado: $odInstalled | Bloqueio OneDrive Policy (1=Sim): $odLocked"
Write-Host "Copilot Desativado (1=Sim): $copilotOff | Recall AI Desativado (1=Sim): $recallOff"
Write-Host "Widgets Barra de Tarefas (0=Off): $widgetsOff | Bing no Iniciar Bloqueado (1=Sim): $bingOff | AllowTelemetry (0=Off): $telemPol"

Get-Service -Name "DiagTrack", "dmwappushservice", "MapsBroker", "RetailDemo", "wisvc" -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType | Format-Table -AutoSize

$bloatCount = (Get-AppxPackage | Where-Object { $_.Name -match "Copilot|Cortana|BingNews|BingWeather|BingSearch|Solitaire|MixedReality|People|WindowsMaps|PowerAutomate|OutlookForWindows|GetHelp|Clipchamp|MSTeams|YourPhone" }).Count
Write-Host "Pacotes Appx de Bloatware detectados no usuario atual: $bloatCount"

