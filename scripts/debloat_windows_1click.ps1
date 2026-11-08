#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Remove bloatware nativo do Windows 10/11 (OneDrive, Copilot, Recall, Widgets, Bing, Jogos/Apps pré-instalados),
    desativa serviços de telemetria (DiagTrack/MapsBroker) e bloqueia reinstalação automática via Políticas de Grupo.
#>
param(
    [switch]$KeepOneDrive,
    [switch]$KeepXbox
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   WINDOWS MASTER OPTIMIZER - DEBLOAT & PRIVACY 1-CLICK   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Desinstalar e Bloquear OneDrive completamente
if (-not $KeepOneDrive) {
    Write-Host "`n[1/5] Removendo e bloqueando Microsoft OneDrive..." -ForegroundColor Yellow
    Stop-Process -Name "OneDrive*" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    $odPaths = @(
        "$env:SystemRoot\System32\OneDriveSetup.exe",
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
        "$env:LOCALAPPDATA\Microsoft\OneDrive\Update\OneDriveSetup.exe"
    )
    foreach ($od in $odPaths) {
        if (Test-Path $od) {
            Start-Process -FilePath $od -ArgumentList "/uninstall" -Wait -NoNewWindow -ErrorAction SilentlyContinue
        }
    }

    # Remover pastas residuais e atalhos do Explorer
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:ProgramData\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\OneDriveTemp" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -ErrorAction SilentlyContinue

    # Política para impedir que o OneDrive volte em atualizações do Windows
    $odPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
    if (-not (Test-Path $odPol)) { New-Item -Path $odPol -Force | Out-Null }
    Set-ItemProperty -Path $odPol -Name "DisableFileSyncNGSC" -Value 1 -Type DWord -Force
    Write-Host "OneDrive desinstalado e bloqueado por politica (DisableFileSyncNGSC=1)." -ForegroundColor Green
}

# 2. Desativar Windows Copilot, Windows Recall (24H2 AI), Widgets, Bing Search e Anúncios (Consumer Features)
Write-Host "`n[2/5] Desativando Copilot, Recall (IA), Widgets, Bing no Iniciar e Anuncios..." -ForegroundColor Yellow

$policies = @(
    @{ Path = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI";      Name = "DisableAIDataAnalysis"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI";      Name = "TurnOffSavingSnapshots"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh";                    Name = "AllowNewsAndInterests"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent";   Name = "DisableWindowsConsumerFeatures"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent";   Name = "DisableSoftLanding"; Value = 1 },
    @{ Path = "HKCU:\Software\Policies\Microsoft\Windows\Explorer";       Name = "DisableSearchBoxSuggestions"; Value = 1 },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search";   Name = "BingSearchEnabled"; Value = 0 },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search";   Name = "CortanaConsent"; Value = 0 },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarDa"; Value = 0 },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowCopilotButton"; Value = 0 },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Start_IrisRecommendations"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge";                   Name = "StartupBoostEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge";                   Name = "BackgroundModeEnabled"; Value = 0 }
)

foreach ($pol in $policies) {
    if (-not (Test-Path $pol.Path)) { New-Item -Path $pol.Path -Force | Out-Null }
    Set-ItemProperty -Path $pol.Path -Name $pol.Name -Value $pol.Value -Type DWord -Force
}
Write-Host "Copilot, Recall, Widgets, Bing Search, Edge Background e Consumer Features desativados." -ForegroundColor Green

# 3. Remover Pacotes Appx (Bloatware Nativo) do Usuário e Provisionados (para novos usuários/updates)
Write-Host "`n[3/5] Removendo aplicativos nativos desnecessarios (Appx Bloatware)..." -ForegroundColor Yellow

$bloatApps = @(
    "Microsoft.Copilot",
    "Microsoft.Windows.Ai.Copilot.Provider",
    "Microsoft.549981C3F5F10", # Cortana
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.BingSearch",
    "Microsoft.BingFinance",
    "Microsoft.BingSports",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MixedReality.Portal",
    "Microsoft.People",
    "Microsoft.WindowsMaps",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.OutlookForWindows",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.Todos",
    "Clipchamp.Clipchamp",
    "MSTeams",
    "Microsoft.YourPhone",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.SkypeApp"
)

foreach ($app in $bloatApps) {
    Get-AppxPackage -Name "*$app*" -AllUsers -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  Removendo pacote: $($_.Name)"
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue
    }
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$app*" } | ForEach-Object {
        Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
    }
}
Write-Host "Pacotes Appx de bloatware removidos e desprovisionados." -ForegroundColor Green

# 4. Desativar Telemetria e Serviços Desnecessários em Segundo Plano
Write-Host "`n[4/5] Desativando servicos de Telemetria (DiagTrack, dmwappushservice, MapsBroker)..." -ForegroundColor Yellow

$dataColl = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (-not (Test-Path $dataColl)) { New-Item -Path $dataColl -Force | Out-Null }
Set-ItemProperty -Path $dataColl -Name "AllowTelemetry" -Value 0 -Type DWord -Force

$servicesToDisable = @(
    "DiagTrack",        # Experiências do Usuário Conectado e Telemetria
    "dmwappushservice", # Serviço de Roteamento de Mensagens Push WAP
    "MapsBroker",       # Gerenciador de Mapas Baixados
    "RetailDemo",       # Serviço de Demonstração de Varejo
    "wisvc"             # Serviço Windows Insider
)

foreach ($svc in $servicesToDisable) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  Servico desativado: $svc"
    }
}

# 5. Desativar Tarefas Agendadas de Telemetria da Microsoft
Write-Host "`n[5/5] Desativando tarefas agendadas de telemetria do Windows..." -ForegroundColor Yellow
$telemetryTasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Autochk\Proxy",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
)
foreach ($t in $telemetryTasks) {
    Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "Debloat concluido! Sistema limpo de OneDrive, Copilot, Recall," -ForegroundColor Green
Write-Host "Widgets, Bing Search, Bloatware UWP e Telemetria em segundo plano." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
