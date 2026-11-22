# FSILVA CLOUD: PROVISIONAMENTO E BLINDAGEM DE VPS
## Infraestrutura Modular, Automatizada e de Alta Performance para Debian 12

Este projeto consiste em um script avançado de automação em Bash desenvolvido para provisionar, endurecer e monitorar servidores virtuais privados (VPS) rodando **Debian GNU/Linux 12 (Bookworm)**. Ele foi arquitetado para eliminar tarefas manuais repetitivas, aplicando padrões rigorosos de segurança de rede, otimização extrema de recursos de hardware e resiliência operacional para ambientes de produção.

---

## 🚀 Funcionalidades Principais

* **Alta Performance de Memória (ZRAM + SWAP):** Configura compressão ZRAM em `zstd` alocando **50% da RAM física**, combinado com um arquivo secundário de SWAP em disco de 6GB para picos operacionais.
* **Proteção Contra Força Bruta (Fail2Ban):** Instala o Fail2Ban com suporte a **Whitelist interativa**, configurando banimento automático de 24 horas após 3 tentativas falhas de login no SSH.
* **Segurança Baseada em Firewall Inteligente:** Detecta dinamicamente a porta SSH em uso, desativa o UFW para evitar conflitos e gerencia regras diretamente no `iptables` (com suporte a menu interativo para o modo **Restrito por Cloudflare** ou **Aberto** nas portas 80/443).
* **Persistência de Regras de Rede:** Utiliza o `iptables-persistent` configurado de forma totalmente não-interativa para garantir que as regras sobrevivem a reboots.
* **Auditoria Visual Automatizada (Raio-X):** Gera um painel detalhado via terminal exibindo saúde do hardware, status das interfaces de rede, volumes do Docker, uso de memória e regras ativas do firewall.

---

## 🛠️ Arquitetura das Fases do Script

### Fases 1 & 2: Otimização de Memória (ZRAM + Swapfile)
* **ZRAM:** Instala o gerenciador `zram-tools`, configurando o algoritmo de compressão `zstd` com prioridade `100` para otimizar o uso da memória RAM.
* **Swapfile:** Cria de forma segura um arquivo de troca de 6GB (`/swapfile`) no disco com permissões restritas (`600`), ativando-o no sistema de arquivos (`/etc/fstab`) para garantir resiliência em picos de consumo.

### Fase 3: Pacotes Base e Fail2Ban (Proteção SSH)
* **Modo Não-Interativo:** Configura automações do `debconf` e o `DEBIAN_FRONTEND=noninteractive` para impedir telas de bloqueio e pop-ups durante a instalação.
* **Repositórios e Utilitários:** Atualiza os pacotes e instala ferramentas essenciais de sistema (`netfilter-persistent`, `iptables-persistent`, `ca-certificates`, `gnupg`, `lsb-release`, `htop`, `unzip`, `tree`, `git`).
* **Ajuste Temporal:** Configura o fuso horário oficial para `America/Sao_Paulo` e sincroniza o relógio atômico via `htpdate` com servidores do Google.
* **Fail2Ban com Whitelist Interativa:** Instala o serviço de proteção SSH, solicita ao usuário os IPs confiáveis para inclusão na lista branca (mantendo o `localhost` protegido por padrão) e aplica regras rígidas com bloqueio de 24 horas (`bantime = 1d`) após 3 tentativas inválidas (`maxretry = 3`).

### Fases 4 & 5: Docker Engine Oficial e Limpeza de Resíduos
* **Instalação Oficial:** Configura as chaves GPG e os repositórios oficiais da Docker no Debian 12, instalando o `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin` e `docker-compose-plugin`, além de habilitar o serviço no boot.
* **Limpeza Automática:** Executa rotinas de limpeza preventiva (`docker container prune`, `docker image prune` e `docker builder prune`) para eliminar lixos e containers órfãos antes de iniciar as operações.

### Fase 6: Firewall Inteligente (IPTABLES + Cloudflare)
* **Anti-Lockout SSH Dinâmico:** Identifica automaticamente a porta real em que o serviço SSH está rodando (`22` ou personalizada) e garante que ela permaneça aberta na tabela `INPUT`.
* **Menu de Segurança Docker (Portas 80/443):**
  * Gerencia o tráfego na cadeia `DOCKER-USER`, permitindo escolher via menu interativo entre o **Modo RESTRITO** (liberando HTTP/HTTPS estritamente para os IPs oficiais da Cloudflare e bloqueando o tráfego direto na porta WAN) ou o **Modo ABERTO** (liberando para qualquer origem).
* **Persistência:** Salva automaticamente o estado das regras via `netfilter-persistent save`.

### Fase 7: Git e GitHub CLI (GH)
* Configura as dependências de versionamento e instala a ferramenta oficial de linha de comando do GitHub (`gh`), permitindo automações de repositórios, autenticação e gerenciamento de fluxos CI/CD diretamente na VPS.

### Fase 8: Hardening do SSH (KeepAlive e Segurança)
* Modifica o arquivo de configuração `/etc/ssh/sshd_config` ajustando os parâmetros de `ClientAliveInterval` e `ClientAliveCountMax` (garantindo que conexões SSH ativas não caiam por ociosidade) e assegurando a integridade e estabilidade do serviço.

### Fase 9: Log de Monitoramento Final (Raio-X Completo)
* Executa uma varredura diagnóstica semestral/final exibindo relatórios formatados em cores no terminal contendo:
  * **Sistema e Hardware:** Versão do Kernel, tempo de atividade (*Uptime*), modelo do processador (*CPU*) e quantidade de pacotes instalados.
  * **Segurança e Firewall:** Status do IPTABLES e listagem enumerada das regras ativas na cadeia `DOCKER-USER`.
  * **Rede:** Endereços IPv4 e IPv6 públicos, tráfego de entrada/saída por interface física/virtual e mapeamento das subredes de pontes do Docker.
  * **Memória e Armazenamento:** Uso detalhado da RAM física, alocação do ZRAM, consumo do Swap em disco e espaço livre na partição raiz (`/`).
  * **Containers:** Identidade, hostnames, IPs internos, status de execução e tabelas de consumo de recursos (*CPU/Memória*) via `docker stats`.

---

## 🖥️ Como Executar

O script exige privilégios de superusuário (**root**) para manipular regras de kernel, firewall e pacotes do sistema.

1. Baixe ou crie o arquivo do script no servidor (ex: `setup.sh`).
2. Conceda permissão de execução:
```bash
chmod +x setup.sh
```
3. Execute o script:
```bash
sudo ./setup.sh
```
