# Setup Absoluto, Firewall e Monitoramento - FSilva Cloud

Este script em Shell Bash automatiza a configuração, otimização de performance, segurança e monitoramento de servidores virtuais (VPS) baseados em **Debian GNU/Linux 12 (Bookworm)** executando a infraestrutura da FSilva Cloud.

---

## 🚀 Funcionalidades Principais

* **Gerenciamento Automático de Travas:** Remove bloqueios residuais do gerenciador de pacotes (`apt`/`dpkg`).
* **Alta Performance de Memória (ZRAM + SWAP):** Configura compressão ZRAM em `zstd` alocando **100% da RAM física**, combinado com um arquivo secundário de SWAP em disco de 4GB para picos de compilação.
* **Segurança Baseada em Firewall Inteligente:** Restringe e isola a cadeia de rede interna do Docker (`DOCKER-USER`), liberando apenas portas essenciais HTTP (`80`) e HTTPS (`443`).
* **Instalação Certificada de Dependências:** Garante e trava o motor do Docker Engine na versão estável `27.3.1`.
* **Auditoria Visual Automatizada (Raio-X):** Gera um dashboard detalhado via terminal exibindo saúde do hardware, status das interfaces de rede, volumes do Docker e containers instáveis.

---

## 🛠️ Arquitetura das Fases do Script

### Fase 1: Dependências de Sistema
Instala ferramentas cruciais de monitoramento de processos, manipulação de texto e gerenciamento de rede (`psmisc`, `util-linux`, `procps`, `sed`, `grep`, `coreutils`, `curl`, `jq`, `bc`, `net-tools`).

### Fase 2: Desbloqueio e Limpeza
Verifica se há processos do `apt` ou `dpkg` travados em background, matando-os de forma segura e limpando os arquivos de trava (`lock`) para evitar falhas de deploy.

### Fase 3: Instalação Silenciosa e Base
Configura o ambiente para ignorar prompts interativos (`DEBIAN_FRONTEND=noninteractive`), atualiza o sistema operacional e instala pacotes base como `htop`, `fail2ban`, `git`, `zram-tools` e sincroniza o relógio atômico com o fuso horário de `America/Sao_Paulo`.

### Fase 4: Performance (ZRAM & SWAP)
Ajusta a otimização de memória do Linux aplicando as seguintes regras físicas:
* **ZRAM (Prioridade 100):** Ativa compressão ultrarrápida na RAM utilizando o algoritmo `zstd` mapeando `PERCENT=100`.
* **SWAPFILE (Prioridade 50):** Cria um arquivo de paginação em disco rígido de 4GB com permissão restrita `600` no diretório `/swapfile`.
* **Swappiness:** Seta `vm.swappiness=60` garantindo estabilidade durante builds pesados que geram alta alocação de memória.

### Fase 5: Configuração do Firewall (IPTABLES DOCKER-USER)
Implementa segurança e isolamento para redes Docker criando e limpando a chain `DOCKER-USER`. Permite tráfego estabelecido, tráfego interno das pontes de rede do Docker e conexões públicas apenas para as portas `80` e `443`. Qualquer outro tráfego externo direcionado aos containers é explicitamente descartado (`DROP`).

### Fase 6: Docker Engine v27 (Opcional Interativo)
Adiciona chaves criptográficas do repositório oficial Docker e instala de maneira fixa as versões:
* `docker-ce=5:27.3.1-1~debian.12~bookworm`
* `docker-ce-cli=5:27.3.1-1~debian.12~bookworm`
Aplica a trava `apt-mark hold` para impedir que atualizações acidentais do sistema quebrem a compatibilidade do motor do Docker.

### Fase 7: Configuração Git (Opcional Interativo)
Configura globalmente a identidade do desenvolvedor no servidor (`user.name` e `user.email`) e adiciona a flag protetiva `safe.directory '*'` para evitar problemas de permissões em repositórios clonados por diferentes usuários dentro dos volumes.

### Fase 8: SSH e Segurança (Opcional Interativo)
Endurece a segurança de acesso ao servidor alterando os parâmetros do arquivo `/etc/ssh/sshd_config` para desativar permanentemente o login por senha (`PasswordAuthentication no`), forçando o uso exclusivo de chaves privadas (SSH Keys).

### Fase 9: Log de Monitoramento Final (Raio-X Completo)
Realiza uma varredura geral em tempo real no servidor coletando dados de hardware e emitindo tabelas formatadas sobre:
* **Identidade:** Sistema operacional, kernel, tempo de atividade (Uptime) e configurações ativas do Git/SSH.
* **Rede:** IPs de interfaces locais, tráfego recebido/enviado em Megabytes e mapeamento de redes internas do Docker.
* **Armazenamento e Memória:** Uso percentual real da RAM, consumo do bloco compactado do ZRAM, uso do SWAP em disco e tamanho ocupado individualmente por cada volume mapeado no Docker.
* **Containers:** Lista o nome de todos os containers ativos, seus respectivos IPs internos na subrede docker, status e contabiliza se há aplicações em loop de falha (`restarting`).
* **SSL:** Contabiliza certificados válidos gerenciados pelo Traefik através do arquivo `acme.json`.

---

## 🖥️ Como Executar

O script exige privilégios de superusuário (**root**) para manipular regras de kernel e firewall.
```bash
apt update && apt install -y curl && curl -sSL https://raw.githubusercontent.com/amazoniacentral/docker-vps/main/setup.sh | sudo bash
```

1. Baixe ou crie o arquivo do script no servidor (ex: `setup.sh`).
2. Conceda permissão de execução:
```bash
chmod +x setup.sh
```
3. Execute o script:
```bash
./setup.sh
```