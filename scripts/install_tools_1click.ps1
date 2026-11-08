#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instalador e configurador 1-Click para ISLC v1.0.3.4 (auto-dimensionado pela RAM + 0.5ms Timer Resolution)
    e ThrottleStop 9.7 (para processadores Intel com início automático via Tarefa Agendada Elevated).
#>
param(
    [string]$InstallDir = "C:\Tools",
    [switch]$SkipThrottleStop
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolsRoot  = Join-Path (Split-Path -Parent $ScriptRoot) "tools"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   1-CLICK INSTALLER: ISLC + THROTTLESTOP + TIMER 0.5MS   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Detectar RAM total e calcular limites ideais do ISLC
$os = Get-CimInstance Win32_OperatingSystem
$totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB)

if ($totalGB -ge 20) {
    $standbyMB = 4096
    $freeMB    = 2048
} elseif ($totalGB -ge 14) {
    $standbyMB = 2048
    $freeMB    = 1536
} else {
    $standbyMB = 1024
    $freeMB    = 1024
}

Write-Host "`n[1/4] RAM Detectada: $totalGB GB -> Configurando ISLC (Standby=$standbyMB MB | Free=$freeMB MB)" -ForegroundColor Yellow

# 2. Habilitar GlobalTimerResolutionRequests no Kernel do Windows 11 e Dynamic Tick
$kernelKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
Set-ItemProperty -Path $kernelKey -Name "GlobalTimerResolutionRequests" -Value 1 -Type DWord -Force
bcdedit /set disabledynamictick yes | Out-Null
bcdedit /deletevalue useplatformclock 2>$null | Out-Null
Write-Host "[2/4] Kernel Timer Global (GlobalTimerResolutionRequests = 1) e DynamicTick desativado." -ForegroundColor Green

# 3. Instalar e Configurar ISLC
$islcDest = Join-Path $InstallDir "ISLC"
New-Item -Path $islcDest -ItemType Directory -Force | Out-Null

Stop-Process -Name "Intelligent standby list cleaner ISLC" -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

$islcSrcExe = Join-Path $ToolsRoot "ISLC\Intelligent standby list cleaner ISLC.exe"
if (Test-Path $islcSrcExe) {
    Copy-Item -Path (Join-Path $ToolsRoot "ISLC\*") -Destination $islcDest -Force
} else {
    throw "Binario do ISLC nao encontrado em $islcSrcExe"
}

$islcConfigPath = Join-Path $islcDest "Intelligent standby list cleaner ISLC.exe.Config"
$configXml = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <startup>
    <supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8"/>
  </startup>
  <appSettings>
    <add key="Standby list" value="$standbyMB" />
    <add key="Free memory" value="$freeMB" />
    <add key="Start minimized" value="True" />
    <add key="Wanted timer" value="0.5000" />
    <add key="Custom timer" value="True" />
    <add key="Polling rateSTR" value="1000" />
    <add key="TaskScheduler" value="True" />
    <add key="OnTop" value="False" />
    <add key="ExclusionList" value="" />
  </appSettings>
</configuration>
"@
Set-Content -Path $islcConfigPath -Value $configXml -Encoding UTF8

$islcExePath = Join-Path $islcDest "Intelligent standby list cleaner ISLC.exe"
$action   = New-ScheduledTaskAction -Execute "`"$islcExePath`"" -WorkingDirectory $islcDest
$trigger  = New-ScheduledTaskTrigger -AtLogOn
$trigger.Delay = "PT15S"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName "Intelligent StandbyList Cleaner" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force | Out-Null

Start-Process -FilePath $islcExePath -WorkingDirectory $islcDest
Write-Host "[3/4] ISLC instalado em $islcDest, agendado como Admin no logon e iniciado a 0.5 ms!" -ForegroundColor Green

# 4. Instalar e Configurar ThrottleStop (se CPU Intel e nao pulado)
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
if (-not $SkipThrottleStop -and $cpu.Manufacturer -match "Intel") {
    $tsDest = Join-Path $InstallDir "ThrottleStop"
    New-Item -Path $tsDest -ItemType Directory -Force | Out-Null
    $tsZip = Join-Path $ToolsRoot "ThrottleStop\ThrottleStop_9.7.zip"
    $tsIni = Join-Path $ToolsRoot "ThrottleStop\ThrottleStop.ini"
    if (Test-Path $tsZip) {
        Stop-Process -Name "ThrottleStop*" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        Expand-Archive -Path $tsZip -DestinationPath $tsDest -Force
        if (-not (Test-Path (Join-Path $tsDest "ThrottleStop.ini")) -and (Test-Path $tsIni)) {
            Copy-Item -Path $tsIni -Destination (Join-Path $tsDest "ThrottleStop.ini") -Force
        }
        $tsExePath = Join-Path $tsDest "ThrottleStop.exe"
        $tsAction  = New-ScheduledTaskAction -Execute "`"$tsExePath`"" -WorkingDirectory $tsDest
        $tsTrigger = New-ScheduledTaskTrigger -AtLogOn
        $tsTrigger.Delay = "PT10S"
        Register-ScheduledTask -TaskName "ThrottleStop_9.7" -Action $tsAction -Trigger $tsTrigger -Settings $settings -RunLevel Highest -Force | Out-Null
        Start-Process -FilePath $tsExePath -WorkingDirectory $tsDest
        Write-Host "[4/4] ThrottleStop 9.7 instalado em $tsDest, agendado com privilegio Admin (Highest) e iniciado!" -ForegroundColor Green
    }
} else {
    Write-Host "[4/4] ThrottleStop ignorado (CPU nao-Intel ou parametro -SkipThrottleStop)." -ForegroundColor DarkGray
}

# Copiar utilitarios extras (FilterKeysSetter e MeasureSleep)
foreach ($util in @("FilterKeysSetter.exe", "MeasureSleep.exe")) {
    $uSrc = Join-Path $ToolsRoot $util
    if (Test-Path $uSrc) { Copy-Item -Path $uSrc -Destination $InstallDir -Force }
}

Write-Host "`nConcluido! Todos os utilitarios estao ativos em $InstallDir." -ForegroundColor Cyan
