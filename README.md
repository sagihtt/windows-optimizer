# Windows Optimizer

Suite de auditoria de telemetria, otimização de baixo nível, remoção de bloatware nativo (**OneDrive**, **Copilot**, **Windows Recall**, **Widgets**, **Telemetria**) e instalação automatizada em **1 Clique** (**ISLC**, **ThrottleStop**, **FilterKeysSetter**, **MeasureSleep** e scripts de manutenção) para Windows 10 e Windows 11.

Desenvolvida tanto para **execução direta em 1 Clique (`.bat`)** quanto como **Skill para o Google Antigravity** (e agentes compatíveis como Claude Code e Cursor), permitindo que o assistente faça uma radiografia completa do hardware e aplique cada ajuste de forma cirúrgica.

---

## Sumário

1. [Problema e Abordagem Técnica](#1-problema-e-abordagem-técnica)
2. [Pilares de Otimização e Debloat](#2-pilares-de-otimização-e-debloat)
3. [Arquitetura do Repositório](#3-arquitetura-do-repositório)
4. [Como Usar com o Google Antigravity (Recomendado)](#4-como-usar-com-o-google-antigravity-recomendado)
5. [Como Usar Direto em 1 Clique (Sem Agente)](#5-como-usar-direto-em-1-clique-sem-agente)
6. [Documentação de Engenharia](#6-documentação-de-engenharia)

---

## 1. Problema e Abordagem Técnica

Grande parte dos scripts de otimização divulgados na internet aplica alterações genéricas herdadas do Windows XP e Windows 7 (como definir `SecondLevelDataCache = 1024`, criar travas de I/O em `IoPageLockLimit`, desativar integralmente o arquivo de paginação `pagefile.sys` ou apagar periodicamente a pasta `C:\Windows\Prefetch`). Em máquinas modernas com SSD NVMe e 16 GB a 32 GB+ de RAM, essas práticas degradam o desempenho, destroem o cache de pré-carregamento e causam fechamentos abruptos (*Out of Memory* por falta de *Commit Charge*) em jogos atuais.

O **Windows Optimizer** opera a partir da leitura real da telemetria do sistema operacional (`audit_system.ps1`), ajustando parâmetros de kernel, interrupções PCIe, energia, memória, rede e políticas de privacidade de acordo com o hardware detectado.

---

## 2. Pilares de Otimização e Debloat

| Módulo | O que é auditado e aplicado |
| :--- | :--- |
| **1. CPU, ACPI CPPC e Turbo Boost** | Inspeciona o Evento ID 55 do `Microsoft-Windows-Kernel-Processor-Power` para detectar travamento de clock base (`100%` vs `141%`) em notebooks gamer (Lenovo IdeaPad Gaming 3i, Acer Nitro, Dell G15) e estabiliza o estado destravado via `HiberbootEnabled = 1` combinado com a regra de *Warm Reboot*. |
| **2. Memória RAM e Pagefile** | Remove travas legadas (`SecondLevelDataCache = 0`, `PagedPoolSize = 0`, remoção de `IoPageLockLimit`) e ativa `LargeSystemCache = 1` e `DisablePagingExecutive = 1` em sistemas com 16 GB+ de RAM, preservando um `pagefile.sys` enxuto para garantia de *Commit Charge*. |
| **3. ISLC e Timer Resolution (`0,5 ms`)** | Instala e agenda o *Intelligent Standby List Cleaner* (v1.0.3.4) com limites calculados automaticamente pelo total de RAM instalada (`4096/2048 MB` para 20 GB+; `2048/1536 MB` para 16 GB; `1024/1024 MB` para 8 GB), habilita `GlobalTimerResolutionRequests = 1` no kernel do Windows 11, desativa `disabledynamictick` e corrige o problema de interpretação decimal (vírgula vs ponto em sistemas PT-BR). |
| **4. ThrottleStop 9.7 (Intel)** | Extrai, configura o `ThrottleStop.ini` (*Speed Shift EPP*, *MMIO Sync*) e registra a Tarefa Agendada no logon com nível de privilégio `Highest` (Administrador) e diretório de trabalho fixo. |
| **5. GPU MSI Mode, HAGS e MMCSS** | Ativa o agendamento de GPU por hardware (`HwSchMode = 2`), define prioridade alta de interrupção PCIe (`DevicePriority = 3` em `Affinity Policy`) na placa de vídeo dedicada, ajusta `Win32PrioritySeparation = 38` (`0x26`), remove o limitador multimídia de rede (`NetworkThrottlingIndex = 0xFFFFFFFF`, `SystemResponsiveness = 10`) e eleva a prioridade de `Tasks\Games`. |
| **6. Energia (`powercfg`) e SSD** | Desativa na tomada (`AC`) a Suspensão Seletiva USB (`48e6b7a6-50f5-4782-a5d4-53bb8f07e226`) e o gerenciamento de energia de estado de link do PCI Express (ASPM), garantindo TRIM ativo e desativando a gravação de `LastAccess` no NTFS. |
| **7. Rede (`TCPNoDelay` Cabo vs Wi-Fi)** | Identifica a placa ativa via `InterfaceGuid` e aplica `TCPNoDelay = 1` (desativando o Algoritmo de Nagle) em qualquer conexão, aplicando `TcpAckFrequency = 1` (*Delayed ACK* off) exclusivamente em interfaces Ethernet (*full-duplex*) para evitar colisão de pacotes `ACK` no ar em redes Wi-Fi (*half-duplex*). |
| **8. Debloat Nativo e Privacidade** | Desinstala o **Microsoft OneDrive** e bloqueia sua reinstalação (`DisableFileSyncNGSC = 1`), desativa **Windows Copilot**, **Windows Recall (IA 24H2)**, **Widgets** (`AllowNewsAndInterests = 0`), busca web do **Bing no Menu Iniciar**, execução em segundo plano do **Microsoft Edge**, remove aplicativos UWP pré-instalados (`BingNews`, `BingWeather`, `Solitaire`, `MixedReality`, `People`, `WindowsMaps`, `PowerAutomate`, `OutlookForWindows`, `Clipchamp`, `MSTeams`) e desativa os serviços `DiagTrack`, `dmwappushservice` e `MapsBroker`. |

---

## 3. Arquitetura do Repositório

```text
windows-optimizer/
├── SKILL.md                             # Definição e fluxo de trabalho da Skill para o Antigravity
├── README.md                            # Documentação principal do projeto
├── references/
│   └── deep-dive.md                     # Fundamentação de engenharia de cada parâmetro e chave do Registro
├── scripts/
│   ├── audit_system.ps1                 # Radiografia completa somente-leitura do PC (8 módulos)
│   ├── 1click_optimize_windows.bat      # [1-Click] Otimização de Kernel, Memória, GPU MSI, MMCSS, Energia e Rede
│   ├── optimize_system_1click.ps1       # Motor PowerShell de otimização do sistema
│   ├── 1click_debloat_windows.bat       # [1-Click] Remoção de OneDrive, Copilot, Recall, Widgets, Bloatware e Telemetria
│   ├── debloat_windows_1click.ps1       # Motor PowerShell de debloat e políticas de privacidade
│   ├── 1click_install_tools.bat         # [1-Click] Instalação e agendamento Admin do ISLC (0.5ms) + ThrottleStop 9.7
│   ├── install_tools_1click.ps1         # Motor PowerShell de instalação dos utilitários
│   └── maintenance/                     # Scripts de manutenção periódica segura
│       ├── clean_temp.bat               # Limpeza de Temp, Windows Update e Lixeira (preservando Prefetch)
│       ├── dev_clean.bat                # Limpeza de caches NPM/Pip e __pycache__ (preservando AppData e venv)
│       ├── health.bat                   # Reparo de imagem e disco (DISM + SFC + CHKDSK + WinSxS Cleanup)
│       ├── network_fix.bat              # Reset de DNS/Winsock/TCP com reaplicação automática do TCPNoDelay
│       └── update_apps.bat              # Atualização silenciosa de programas via Winget com auto-elevação Admin
└── tools/                               # Binários integrados para instalação 100% offline
    ├── ISLC/                            # Intelligent Standby List Cleaner v1.0.3.4
    ├── ThrottleStop/                    # ThrottleStop 9.7 + configuração base
    ├── FilterKeysSetter.exe             # Ajuste de taxa de repetição de teclado
    └── MeasureSleep.exe                 # Validador de precisão do Timer Resolution (0.5 ms)
```

---

## 4. Como Usar com o Google Antigravity (Recomendado)

Ao instalar este repositório como uma **Skill** no **Google Antigravity**, o agente passa a conhecer todos os scripts, diagnósticos de eventos do kernel e regras de segurança para auditar e otimizar qualquer máquina Windows de ponta a ponta.

### Passo 1: Instalar a Skill
Abra o terminal (PowerShell) e clone o repositório diretamente na pasta de skills do Antigravity:

```powershell
git clone https://github.com/sagihtt/windows-optimizer "$env:USERPROFILE\.gemini\config\skills\windows-optimizer"
```

*(Caso utilize também o Antigravity CLI ou Claude Code, você pode espelhar a pasta em `$env:USERPROFILE\.gemini\antigravity-cli\skills\windows-optimizer` ou `$env:USERPROFILE\.claude\skills\windows-optimizer`).*

### Passo 2: Pedir ao Antigravity para Otimizar o PC
Abra o chat do Antigravity e envie:

> *"Use a skill windows-optimizer para fazer uma radiografia completa do meu PC, limpar todas as tranqueiras nativas (OneDrive, Copilot, Telemetria), instalar o ISLC configurado para a minha RAM e aplicar todas as otimizações de desempenho."*

O agente executará primeiro o `audit_system.ps1`, mostrará o diagnóstico detalhado do seu hardware e aplicará os ajustes necessários.

---

## 5. Como Usar Direto em 1 Clique (Sem Agente)

Se preferir executar manualmente em qualquer computador recém-formatado ou lento:

1. Baixe ou clone este repositório.
2. Acesse a pasta `scripts/` e execute os três módulos dando dois cliques:
   * **`1click_optimize_windows.bat`**: Ajusta Memória RAM, GPU MSI Mode, HAGS, MMCSS para Jogos, Energia USB/PCIe e `TCPNoDelay` na rede.
   * **`1click_debloat_windows.bat`**: Remove OneDrive, desativa Copilot, Recall, Widgets, Bing no Iniciar, Bloatware UWP e serviços de Telemetria (`DiagTrack`).
   * **`1click_install_tools.bat`**: Instala em `C:\Tools` o **ISLC** (auto-configurado para `0,5 ms` e para o tamanho da sua RAM) e o **ThrottleStop 9.7**, registrando ambos no Agendador de Tarefas do Windows como Administrador.
3. Ao concluir, utilize a opção **Reiniciar** do Menu Iniciar (não utilize *Desligar*) para que o Windows recarregue todas as chaves do Registro do zero.

---

## 6. Documentação de Engenharia

Para entender em profundidade o funcionamento de cada parâmetro de kernel, consulte o documento [`references/deep-dive.md`](references/deep-dive.md).
