# Infra VPS Docker - FSilva 🚀

Este repositório contém o script de provisionamento automatizado para transformar uma VPS **Debian 12 Bookworm** limpa em um servidor de produção de alta performance, pronto para orquestrar containers Docker com o proxy.

## 🛠 O que o Script faz?

O script executa uma configuração de "Endurecimento" (Hardening) e Otimização dividida em 6 pilares estratégicos:

### 1. Preparação e Atualização do Sistema
* **Correção de Repositórios:** Limpa entradas antigas do Docker para evitar conflitos de pacotes.
* **Update & Upgrade:** Sincroniza o sistema com os patches de segurança mais recentes.
* **Sincronização de Tempo:** Configura o fuso horário para `America/Sao_Paulo` e sincroniza o relógio via `htpdate` para garantir que os certificados SSL não falhem por diferença de horário.

### 2. Stack Docker v27 (Estabilidade de Produção)
* **Repositório Oficial:** Instala as chaves GPG e configura o repositório oficial da Docker Inc.
* **Versão Fixa:** Instala especificamente a versão `27.3.1` e aplica um `apt-mark hold` para evitar atualizações automáticas que possam causar downtime imprevisto.
* **Habilitação:** Configura o serviço para iniciar automaticamente com o sistema.

### 3. Segurança e Firewall (UFW & Fail2Ban)
* **Política Restritiva:** Reseta o firewall e define bloqueio total de entrada por padrão.
* **Portas Abertas:** Libera apenas o essencial: **22/TCP (SSH)**, **80/TCP (HTTP)** e **443/TCP (HTTPS)**.
* **Fail2Ban:** Ativado para mitigar ataques de força bruta no acesso SSH.

### 4. Gestão de Memória Híbrida (Expansão de RAM)
Implementa uma hierarquia inteligente para que a VPS suporte cargas de trabalho muito superiores à RAM física nominal:
* **ZRAM (Camada 1):** Cria um dispositivo comprimido com **ZSTD** usando 50% da RAM física. Prioridade máxima por ser extremamente rápida.
* **SWAP de Disco (Camada 2):** Cria um arquivo de reserva de **4GB** no SSD.
* **Ajuste de Swappiness:** Define o kernel para `vm.swappiness=10`, garantindo que o sistema priorize a RAM/ZRAM e só use o disco em caso de necessidade extrema.

### 5. Orquestração
* **Rede Docker:** Cria a rede externa `web` para comunicação isolada entre containers.


## 🚀 Instalação Rápida (One-Liner)

Se você está em uma VPS Debian 12 recém-criada, execute o comando abaixo para configurar toda a infraestrutura automaticamente:

```bash
apt update && apt install -y wget unzip && \
wget https://github.com/amazoniacentral/docker-vps/archive/refs/heads/main.zip -O setup.zip && \
unzip -o setup.zip && cd docker-vps-main && sudo bash install
```

---
**Desenvolvido por Francisco Silva (FSilva) — 2026** *Licença: MIT*
