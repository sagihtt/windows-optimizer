---
name: windows-optimizer
description: Use when auditing, diagnosing, debloating, or optimizing a new, slow, or misconfigured Windows 10/11 PC or gaming laptop, removing native bloatware (OneDrive, Copilot, Recall, Widgets, Telemetry), or installing/configuring ISLC, ThrottleStop, and maintenance scripts in 1 click.
metadata:
  category: technique
  triggers: windows optimization, otimizar pc, otimizar windows, debloat windows, remover onedrive, desativar copilot, cpu presa no clock base, turbo boost travado, islc timer resolution, throttlestop 1 click, memory management registry, msi mode gpu, mmcss games, tcpnodelay, scripts de manutencao
---

# Windows Optimizer

Diagnóstico de telemetria, otimização de baixo nível, remoção de bloatware nativo (**OneDrive**, **Copilot**, **Windows Recall**, **Widgets**, **Bing Search**, **Telemetria**) e instalação 1-Click de utilitários de performance (**ISLC**, **ThrottleStop**, **FilterKeysSetter**, **MeasureSleep** e scripts de manutenção) para Windows 10/11.

## Quando Usar

- Computador novo, recém-formatado ou lento que precisa ficar limpo de bloatware e configurado para desempenho máximo e baixa latência.
- Remoção definitiva e bloqueio por política de grupo do **OneDrive**, **Windows Copilot**, **Windows Recall (IA 24H2)**, **Widgets**, **Busca Bing no Menu Iniciar**, **Edge em segundo plano**, aplicativos UWP pré-instalados e serviços de telemetria (`DiagTrack`).
- Processador travado no clock base (ex.: `3,11 GHz`) sem subir o Turbo Boost após ligar o notebook.
- Instalação e configuração em 1 clique do **ISLC** (dimensionado automaticamente pela quantidade de RAM + Timer Resolution em `0,5 ms`) e do **ThrottleStop 9.7** (com Tarefa Agendada em modo Administrador).
- Ajuste fino de memória RAM (8 GB, 16 GB, 24 GB, 32 GB+), `pagefile.sys`, cache do Windows (`Standby List`), interrupções MSI da GPU, agendador `MMCSS` e latência de rede (`TCPNoDelay`).
- Auditoria ou execução dos scripts de manutenção (`clean_temp.bat`, `dev_clean.bat`, `health.bat`, `network_fix.bat`, `update_apps.bat`).

---

## Estrutura de Ferramentas e Scripts em 1 Clique

| Recurso | Caminho Relativo | Função |
|---|---|---|
| **Radiografia Completa (Somente-Leitura)** | [`scripts/audit_system.ps1`](scripts/audit_system.ps1) | Inspeciona CPU/ACPI, RAM/Pagefile, Timer Resolution real (`ntdll.dll`), GPU MSI Mode, Energia, Rede, Inicialização e Bloatware/Telemetria em 3 segundos. |
| **Otimização de Kernel, GPU, RAM e Rede (1-Click)** | [`scripts/1click_optimize_windows.bat`](scripts/1click_optimize_windows.bat) / [`scripts/optimize_system_1click.ps1`](scripts/optimize_system_1click.ps1) | Aplica os ajustes de Kernel, Memória (proporcional à RAM), GPU MSI High Priority, HAGS, MMCSS Games, Energia (USB/PCIe ASPM) e Rede (`TCPNoDelay` inteligente para Cabo vs Wi-Fi). |
| **Debloat & Privacidade Nativa (1-Click)** | [`scripts/1click_debloat_windows.bat`](scripts/1click_debloat_windows.bat) / [`scripts/debloat_windows_1click.ps1`](scripts/debloat_windows_1click.ps1) | Desinstala e bloqueia OneDrive, desativa Copilot, Recall AI, Widgets, Bing no Iniciar, anúncios, Edge em 2º plano, remove apps Appx inúteis e desativa `DiagTrack` e tarefas de telemetria. |
| **Instalador 1-Click (ISLC + ThrottleStop)** | [`scripts/1click_install_tools.bat`](scripts/1click_install_tools.bat) / [`scripts/install_tools_1click.ps1`](scripts/install_tools_1click.ps1) | Instala os binários de `tools/` em `C:\Tools`, calcula os limites do ISLC pela RAM total, ativa `GlobalTimerResolutionRequests = 1` + `0.5 ms`, extrai o ThrottleStop (se CPU Intel) e cria as Tarefas Agendadas com privilégio máximo (`Highest`). |
| **Scripts de Manutenção Limpos** | [`scripts/maintenance/`](scripts/maintenance/) | `clean_temp.bat` (preserva Prefetch), `dev_clean.bat` (preserva AppData/venv), `health.bat` (DISM + SFC + CHKDSK), `network_fix.bat` (reset + reaplica TCPNoDelay) e `update_apps.bat` (Winget Admin). |
| **Referência Técnica Profunda** | [`references/deep-dive.md`](references/deep-dive.md) | Explicação detalhada de engenharia sobre cada chave do Registro, ACPI CPPC, bug de vírgula do ISLC, políticas de Debloat e diferença entre Cabo e Wi-Fi. |

---

## Fluxo de Trabalho Obrigatório para o Agente

### Passo 1: Rodar a Radiografia (`audit_system.ps1`)
Sempre execute primeiro [`scripts/audit_system.ps1`](scripts/audit_system.ps1) para ler o estado exato da máquina antes de sugerir ou aplicar mudanças:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<caminho_da_skill>\scripts\audit_system.ps1"
```

### Passo 2: Diagnóstico e Aplicação Cirúrgica (8 Pilares)

#### 1. CPU, Turbo Boost (ACPI CPPC) e Inicialização Rápida (`HiberbootEnabled`)
* **Verificação:** Olhe o Evento **ID 55** do `Microsoft-Windows-Kernel-Processor-Power` no resultado da auditoria:
  * `Percentual de desempenho máximo: 100` $\rightarrow$ O processador subiu travado no clock base por bug de inicialização fria (`0x0`) da BIOS/EC.
  * `Percentual de desempenho máximo: > 100` (ex.: `141`) $\rightarrow$ O Turbo Boost está destravado.
* **Como estabilizar:** Com o processador destravado, mantenha `HiberbootEnabled = 1` em `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power`. Assim, o **Desligar** hiberna o kernel (`0x1`) guardando o estado destravado.
* **Regra do Reiniciar:** Sempre que alterar chaves do Registro (`HKLM\SYSTEM`), oriente o usuário a usar **Reiniciar** (nunca **Desligar**), pois o *Fast Startup* congela o kernel antigo e não recarrega o Registro no *Desligar*, enquanto o **Reiniciar** recarrega tudo a quente mantendo o Turbo Boost ativo.

#### 2. Memória RAM, Pagefile e Limpeza de Chaves Legadas
* **Nunca desative o `pagefile.sys`:** Jogos modernos exigem *Commit Charge* respaldado por arquivo de paginação e fecham sozinhos se ele for desativado, mesmo com 24 GB ou 32 GB de RAM. Mantenha um `pagefile.sys` pequeno (ex.: `2560 MB`); o uso real (`CurrentUsage`) ficará em `0 MB`.
* **Em `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management`:**
  * Zere `SecondLevelDataCache = 0` e `PagedPoolSize = 0`, e remova `IoPageLockLimit` (chaves da época do Windows XP que limitam CPUs e NVMe modernos).
  * Se a máquina tiver **16 GB+ de RAM**, ative `LargeSystemCache = 1` e `DisablePagingExecutive = 1`.

#### 3. Instalação 1-Click do ISLC e ThrottleStop (`install_tools_1click.ps1`)
* O script [`scripts/install_tools_1click.ps1`](scripts/install_tools_1click.ps1) automatiza tudo:
  * Detecta a RAM total e grava no `.Config` do ISLC os valores ideais (`4096 / 2048` para 20 GB+; `2048 / 1536` para 16 GB; `1024 / 1024` para 8 GB).
  * Ativa `GlobalTimerResolutionRequests = 1` no kernel do Windows 11 e `bcdedit /set disabledynamictick yes` para que o timer de **`0,5 ms`** funcione globalmente mesmo com o ISLC minimizado na bandeja.
  * **Nota sobre edição manual na janela do ISLC:** No arquivo `.Config` XML usa-se ponto (`0.5000`), mas na tela do programa em Windows PT-BR é obrigatório digitar **`0,50` com vírgula** (com ponto ele lê `5000 ms` e trava em `15,625 ms`).
  * Registra as Tarefas Agendadas do **ISLC** e do **ThrottleStop 9.7** com `RunLevel = Highest` (Administrador) e `WorkingDirectory` configurado, evitando pop-ups de UAC ou perda do arquivo `ThrottleStop.ini` no login.

#### 4. GPU, MSI Mode (`DevicePriority`) e Agendador Multimídia (`MMCSS`)
* Ative o agendamento de GPU por hardware (`HwSchMode = 2`), desative o `GameDVR_Enabled = 0` e ajuste `Win32PrioritySeparation = 38` (`0x26`).
* Na chave PCIe da GPU dedicada (`...\Interrupt Management`), garanta `MSISupported = 1` e `Affinity Policy\DevicePriority = 3` (*High*).
* Em `Multimedia\SystemProfile`, configure `SystemResponsiveness = 10`, `NetworkThrottlingIndex = 0xFFFFFFFF` e a subchave `Tasks\Games` com `Scheduling Category = High`, `SFIO Priority = High`, `Priority = 6` e `GPU Priority = 8`.

#### 5. Plano de Energia: Subconfigurações Ocultas (`powercfg`)
* Desative na tomada (`AC`) o **PCIe Link State Power Management (ASPM)** e a **Suspensão Seletiva USB** (`48e6b7a6-50f5-4782-a5d4-53bb8f07e226 = 0`) para eliminar micro-desconexões e latência em periféricos USB.

#### 6. Rede: `TCPNoDelay` vs `TcpAckFrequency` (Cabo vs Wi-Fi)
* Sempre localize a interface ativa no Registro pelo `InterfaceGuid` (`Get-NetAdapter | Where-Object Status -eq 'Up'`), nunca por `InterfaceIndex`.
* Aplique `TCPNoDelay = 1` (desativa o Algoritmo de Nagle) tanto no Cabo quanto no Wi-Fi.
* Aplique `TcpAckFrequency = 1` (desativa o *Delayed ACK*) **apenas em conexões via Cabo Ethernet (*full-duplex*)**. No **Wi-Fi (*half-duplex*)**, mantenha o padrão do Windows para evitar disputa de pacotes `ACK` no ar durante downloads pesados.

#### 7. Debloat Nativo, Remoção de OneDrive, Copilot, Recall e Telemetria (`debloat_windows_1click.ps1`)
* O script [`scripts/debloat_windows_1click.ps1`](scripts/debloat_windows_1click.ps1) (ou [`scripts/1click_debloat_windows.bat`](scripts/1click_debloat_windows.bat)) limpa todas as "tranqueiras" nativas do Windows 10/11:
  * **OneDrive:** Encerra o processo, executa `OneDriveSetup.exe /uninstall`, limpa pastas residuais e grava `DisableFileSyncNGSC = 1` em `HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive` para impedir que o Windows Update o reinstale.
  * **Copilot, Recall AI (24H2) e Widgets:** Ativa as políticas `TurnOffWindowsCopilot = 1`, `DisableAIDataAnalysis = 1`, `TurnOffSavingSnapshots = 1` e `AllowNewsAndInterests = 0` (eliminando o consumo de RAM do `Widgets.exe` / `WebExperience`).
  * **Menu Iniciar Limpo e Edge sem 2º Plano:** Desativa a busca web do Bing no Iniciar (`DisableSearchBoxSuggestions = 1`, `BingSearchEnabled = 0`), remove recomendações/propagandas (`DisableWindowsConsumerFeatures = 1`, `Start_IrisRecommendations = 0`) e bloqueia o `StartupBoostEnabled = 0` e `BackgroundModeEnabled = 0` do Microsoft Edge.
  * **Remoção de Apps UWP (Appx) e Telemetria:** Desinstala e desprovisiona pacotes inúteis (`BingNews`, `BingWeather`, `BingSearch`, `Solitaire`, `MixedReality`, `People`, `WindowsMaps`, `PowerAutomate`, `OutlookForWindows`, `GetHelp`, `Clipchamp`, `MSTeams`, `YourPhone`, `Todos`) e desativa os serviços `DiagTrack`, `dmwappushservice`, `MapsBroker` e tarefas agendadas do *Customer Experience Improvement Program*.

#### 8. Scripts de Manutenção (`scripts/maintenance/`)
* Nunca apague `C:\Windows\Prefetch` em limpezas de rotina (`clean_temp.bat`), pois isso destrói o cache de abertura rápida que o Windows monta na RAM.
* Em `dev_clean.bat`, sempre exclua `AppData`, `venv`, `.venv`, `site-packages` e `node_modules` ao apagar pastas `__pycache__`.
