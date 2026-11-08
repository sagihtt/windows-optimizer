# Referência Técnica Profunda — Windows Master Optimizer

Este documento detalha o funcionamento interno do kernel do Windows 10/11, ACPI, gerenciador de memória, interrupções PCIe e pilha TCP/IP para fundamentar cada decisão da skill `windows-master-optimizer`.

---

## 1. ACPI CPPC, Turbo Boost Preso no Clock Base e `HiberbootEnabled`

### O Problema Físico / Firmware
Em diversos notebooks gamer Intel (como Lenovo IdeaPad Gaming 3i, Dell G15 e Acer Nitro), o controlador embarcado (EC/BIOS) ocasionalmente publica a tabela **ACPI CPPC** (*Collaborative Processor Performance Control*) durante um boot frio (`0x0`) com `HighestPerformance = 100%` em vez do teto real do Turbo Boost (ex.: `141%` para um i5-11300H cujo base é 3,11 GHz e o Turbo é 4,40 GHz).

### Como o Kernel do Windows Reage
1. Durante a inicialização do kernel, o driver `intelppm.sys` lê a tabela CPPC e registra o **Evento ID 55** no log `Microsoft-Windows-Kernel-Processor-Power`.
2. Se o Evento 55 registrar `Percentual de desempenho máximo: 100`, nenhum software no Windows (nem mesmo o plano *Ultimate Performance* ou o *ThrottleStop*) consegue fazer o clock passar da frequência nominal, porque o próprio kernel trata `100%` como o teto físico do hardware naquela sessão.
3. Ao dar **Reiniciar** no Windows com o notebook já energizado, a placa-mãe faz um *warm reset* (`0x0`) onde o EC publica corretamente `Percentual de desempenho máximo: 141`.

### A Solução Definitiva (`HiberbootEnabled = 1` + Regra do Reiniciar)
* Quando o processador sobe destravado (`141%`), ativar a Inicialização Rápida (`HiberbootEnabled = 1` em `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power`) faz com que o comando **Desligar** salve o estado do kernel e dos drivers (incluindo a tabela ACPI destravada) em `hiberfil.sys` (boot tipo `0x1`).
* **Atenção:** Como o **Desligar** hiberna o kernel, ele **não relê chaves de sistema (`HKLM\SYSTEM`)** na próxima vez que ligar. Portanto, sempre que alterar chaves de Registro de memória, rede ou hardware, é obrigatório usar **Reiniciar** (que executa um boot `0x0` a quente, recarregando o Registro e mantendo o Turbo Boost destravado).

---

## 2. Gerenciador de Memória do Windows, `pagefile.sys` e Chaves Legadas

### Por que NUNCA desativar o `pagefile.sys`
* O gerenciador de memória do Windows separa **Memória Física (RAM)** de **Commit Charge (Memória Virtual Comprometida)**.
* Quando uma engine de jogo (Unreal, Frostbite, REDengine, Source 2) aloca blocos de memória com `VirtualAlloc(..., MEM_COMMIT)`, o Windows exige que exista espaço total de *Commit Limit* (`RAM + Pagefile`) para garantir a reserva, mesmo que o jogo nunca escreva um único byte naquela região.
* Sem `pagefile.sys`, o *Commit Limit* fica restrito à RAM física e chamadas de alocação falham com *Out of Memory* mesmo com 10 GB de RAM livre.
* **Configuração ideal para 16 GB–32 GB+:** Manter um `pagefile.sys` pequeno no SSD NVMe (ex.: `2560 MB` a `4096 MB`). O indicador `CurrentUsage` em `Win32_PageFileUsage` permanecerá em `0 MB`, garantindo zero desgaste no SSD e zero crashes.

### Chaves do Registro em `Session Manager\Memory Management`
| Chave | Valor Recomendado (16GB+) | Por quê? |
|---|---|---|
| `LargeSystemCache` | `1` | Instrui o Windows a usar toda a RAM ociosa para cache de arquivos de sistema e disco (*Standby List*), acelerando aberturas repetidas. |
| `DisablePagingExecutive` | `1` | Impede que páginas de código do kernel e drivers `.sys` sejam enviadas para o disco, mantendo-as sempre na RAM física. |
| `SecondLevelDataCache` | `0` | **Armadilha de scripts antigos:** Era usada no Windows NT 4.0/XP quando o sistema falhava ao ler cache L2. Definir `1024` (1 MB) engana o agendador sobre a geometria real do cache L2/L3. Deve ser sempre `0` (detecção via CPUID). |
| `PagedPoolSize` | `0` | `0` habilita alocação dinâmica pelo kernel. Valores fixos limitam a tabela de handles e descritores. |
| `IoPageLockLimit` | *(Remover)* | Ignorada desde o Windows Vista/7 ou restritiva em I/O legados; deve ser removida. |

---

## 3. Funcionamento Interno do ISLC e do Timer Resolution (`0,5 ms`)

### Como o Timer do Kernel Funciona (`NtQueryTimerResolution`)
* O relógio de interrupção padrão do Windows bate a cada **`15,625 ms`** (64 Hz). Isso afeta `Sleep(1)`, agendamento de threads e *frame pacing*.
* A função não-documentada `NtSetTimerResolution` na `ntdll.dll` permite baixar o intervalo para **`0,5 ms`** (`5000` unidades de 100 ns).
* No **Windows 11**, a Microsoft alterou o comportamento padrão: se uma janela estiver minimizada ou em segundo plano, o pedido de Timer Resolution dela deixa de valer para os outros processos, **a menos que** a chave `GlobalTimerResolutionRequests = 1` (DWORD) exista em `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel`.

### O Bug de Localização (Vírgula vs Ponto) no ISLC
* Ao ler o arquivo XML `Intelligent standby list cleaner ISLC.exe.Config` na inicialização (`GetConfigFile`), o ISLC usa `Single.TryParse(..., CultureInfo.InvariantCulture)`, aceitando `0.5000` com ponto.
* Porém, na interface gráfica WPF (caixa *Wanted timer resolution*), o *data binding* do .NET usa a cultura do idioma do Windows (`pt-BR`). Se o usuário digitar `0.50` com ponto na tela, o parser brasileiro ignora o ponto como separador de milhar e interpreta `50` ou `5000`, travando o timer em `15,625 ms`. Na tela em PT-BR, deve-se digitar **`0,50`** (com vírgula).

### Lógica Booleana da Limpeza de Cache (`PurgeLogic`)
* O ISLC avalia: `if (StandbyListMB >= Limit1 AND FreeMemoryMB < Limit2) -> NtSetSystemInformation(MemoryPurgeStandbyList)`.
* Em PCs com 24 GB ou 32 GB, deixar `1024 / 1024` é muito conservador; configurar **`4096 MB`** (Standby List) e **`2048 MB`** (Free Memory) deixa o Windows acumular até 18+ GB de cache rápido na RAM e só limpa se a memória livre cair abaixo de 2 GB.

---

## 4. Rede: `TCPNoDelay` (Nagle) vs `TcpAckFrequency` (Delayed ACK)

* **`TCPNoDelay = 1`:** Desativa o Algoritmo de Nagle (`RFC 896`), que retém pacotes pequenos no buffer de saída aguardando o `ACK` do pacote anterior ou o preenchimento do MSS (*Maximum Segment Size*). Essencial tanto em **Cabo** quanto em **Wi-Fi**.
* **`TcpAckFrequency = 1`:** Desativa o *Delayed ACK* (`RFC 1122`), fazendo a pilha TCP enviar um pacote `ACK` imediatamente para cada segmento recebido, em vez de aguardar o 2º segmento ou o timer de 40–200 ms.
  * **Em Cabo Ethernet (Full-Duplex):** Os pares TX e RX são separados fisicamente; enviar `ACK` em dobro reduz a latência percebida pelo servidor sem afetar o download.
  * **Em Wi-Fi (Half-Duplex CSMA/CA):** O rádio não transmite e recebe no mesmo canal simultaneamente. Dobrar a taxa de pacotes `ACK` na subida aumenta a contenção de tempo de ar (*airtime*) em downloads pesados. Por isso, o script 1-Click aplica `TcpAckFrequency = 1` apenas em adaptadores Ethernet e mantém apenas `TCPNoDelay = 1` no Wi-Fi.

---

## 5. Debloat Nativo, Políticas de Grupo e Telemetria (`debloat_windows_1click.ps1`)

### Por que usar Políticas de Grupo (`HKLM:\SOFTWARE\Policies`) além de desinstalar
No Windows 10/11, apenas remover pacotes Appx ou fechar processos não impede que atualizações cumulativas reinstalem o **OneDrive**, reativem o **Copilot**, o **Windows Recall (24H2)** ou baixem aplicativos patrocinados (*Candy Crush*, *TikTok*, *Novo Outlook*).

O script `debloat_windows_1click.ps1` aplica bloqueios definitivos via chaves de Política de Grupo:
* **OneDrive (`HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive\DisableFileSyncNGSC = 1`):** Impede a execução e a recriação da sincronização após o `OneDriveSetup.exe /uninstall`.
* **Windows Copilot (`TurnOffWindowsCopilot = 1`) e Windows Recall AI (`DisableAIDataAnalysis = 1`, `TurnOffSavingSnapshots = 1`):** Desativa os agentes de IA em segundo plano e a captura contínua de tela do Windows 11 24H2.
* **Widgets (`HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0` e `TaskbarDa = 0`):** Impede o carregamento do `Widgets.exe` e dos processos `msedgewebview2.exe` atrelados ao painel de notícias, economizando de 200 MB a 500 MB de RAM.
* **Consumer Features (`DisableWindowsConsumerFeatures = 1`):** Bloqueia o download silencioso de jogos e aplicativos promocionais da Microsoft Store.
* **Busca Local Rápida (`DisableSearchBoxSuggestions = 1`):** Corta requisições HTTP ao Bing a cada tecla digitada no Menu Iniciar, tornando a busca instantânea e 100% local.
* **Serviços de Telemetria (`DiagTrack` e `dmwappushservice`):** Apenas definir `AllowTelemetry = 0` em edições Home/Pro não encerra o serviço `DiagTrack` (*Connected User Experiences and Telemetry*). Desativar o serviço (`StartupType = Disabled`) e as tarefas agendadas do *Application Experience* (`CompatTelRunner.exe`) elimina picos de uso de disco e CPU em segundo plano.

