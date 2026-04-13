#!/bin/bash
set -e

# =================================================================
# SCRIPT DE SETUP E MONITORAMENTO VPS - FSilva Cloud
# =================================================================

# 1. Verificar se é root
if [ "$EUID" -ne 0 ]; then 
  echo "Erro: Execute este script como root."
  exit 1
fi

# Cores para o terminal
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

clear
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           INICIANDO PREPARAÇÃO AUTOMÁTICA DA VPS${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# --- PARTE 1: AUTOMÁTICA (SISTEMA E MEMÓRIA) ---

echo "== Removendo conflitos e limpando APT =?"
# Remove UFW que causa quebra de pacotes com iptables-persistent
apt remove --purge -y ufw || true
apt autoremove -y
apt --fix-broken install -y

echo "== Atualizando sistema =="
apt update && apt upgrade -y

echo "== Instalando pacotes básicos e persistência de firewall =="
# Instalando netfilter-persistent primeiro para evitar erro de dependência
apt install -y netfilter-persistent
apt install -y ca-certificates curl gnupg lsb-release htop unzip zram-tools htpdate fail2ban tree bc iptables-persistent

# Ajustar Relógio
timedatectl set-timezone America/Sao_Paulo
htpdate -s -t google.com

echo "== Configurando ZRAM (Camada 1: RAM Comprimida) =="
cat <<EOF > /etc/default/zramswap
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
systemctl restart zramswap

echo "== Configurando Swap de Disco (Camada 2: 4GB de Reserva) =="
if [ ! -f /swapfile ]; then
  echo "Criando swapfile..."
  fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
  chmod 600 /swapfile
  mkswap /swapfile
fi

sed -i '/\/swapfile/d' /etc/fstab
echo "/swapfile none swap sw,pri=10 0 0" >> /etc/fstab
swapoff /swapfile 2>/dev/null || true
swapon -p 10 /swapfile

echo "== Otimizando Kernel (Swappiness) =="
sed -i '/vm.swappiness/d' /etc/sysctl.conf
echo "vm.swappiness=10" >> /etc/sysctl.conf
sysctl -p

# --- PARTE 2: PERGUNTAS (DOCKER) ---

echo -e "\n${YELLOW}--------------------------------------------------${RESET}"
read -p "Deseja instalar o Docker v27? (s/n): " INSTALL_DOCKER < /dev/tty
if [[ "$INSTALL_DOCKER" =~ ^[Ss]$ ]]; then
    echo "== Configurando Repositório Docker (Debian) =="
    install -m 0755 -d /etc/apt/keyrings
    rm -f /etc/apt/keyrings/docker.gpg
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update

    echo "== Instalando Docker v27 =="
    apt install -y --allow-downgrades \
      docker-ce=5:27.3.1-1~debian.12~bookworm \
      docker-ce-cli=5:27.3.1-1~debian.12~bookworm \
      containerd.io docker-buildx-plugin docker-compose-plugin

    apt-mark hold docker-ce docker-ce-cli
    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}Docker instalado e bloqueado na v27.${RESET}"
else
    echo "Instalação do Docker pulada."
fi

# --- PARTE 3: PERGUNTAS (GIT) ---

echo -e "\n${YELLOW}--------------------------------------------------${RESET}"
read -p "Deseja instalar e configurar o Git? (s/n): " CONFIRM_GIT < /dev/tty
if [[ "$CONFIRM_GIT" =~ ^[Ss]$ ]]; then
    echo "Instalando Git..."
    apt update && apt install -y git

    echo -n "Digite o Nome do Git: "
    read -r GIT_USER < /dev/tty
    echo -n "Digite o E-mail do Git: "
    read -r GIT_EMAIL < /dev/tty

    git config --global user.name "$GIT_USER"
    git config --global user.email "$GIT_EMAIL"
    git config --global --add safe.directory '*'
    echo -e "${GREEN}GIT CONFIGURADO COM SUCESSO.${RESET}"
else
    echo "Configuração do Git pulada."
fi

# --- PARTE 4: PERGUNTAS (SSH E SEGURANÇA) ---

echo -e "\n${YELLOW}--------------------------------------------------${RESET}"
read -p "Deseja criar chave SSH e DESATIVAR SENHAS? (s/n): " CONFIRM_SSH < /dev/tty
if [[ "$CONFIRM_SSH" =~ ^[Ss]$ ]]; then
    echo "Gerando chave SSH Ed25519..."
    SSH_FILE="$HOME/.ssh/id_ed25519"
    mkdir -p "$HOME/.ssh"
    if [ ! -f "$SSH_FILE" ]; then
        ssh-keygen -t ed25519 -C "${GIT_EMAIL:-vps@fcloud}" -f "$SSH_FILE" -N ""
        eval "$(ssh-agent -s)"
        ssh-add "$SSH_FILE"
    fi

    echo "== Aplicando Proteção Extra SSH (Bloqueio de Senhas) =="
    sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    # Garante que não existam duplicatas e que o UsePAM não interfira se necessário
    systemctl restart ssh
    
    echo -e "${GREEN}SSH CONFIGURADO. ACESSO POR SENHA BLOQUEADO.${RESET}"
    echo "Sua Chave Pública SSH:"
    cat "${SSH_FILE}.pub"
else
    echo "Configuração de segurança SSH pulada."
fi

echo "== Limpeza final =="
apt autoremove -y && apt autoclean

# --- PARTE 5: RELATÓRIO DE STATUS FINAL ---


echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           STATUS GERAL DA VPS (PÓS-CONFIGURAÇÃO)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

UPTIME_ALIVE=$(uptime -p | sed 's/up //')
OS_VERSION=$(grep "PRETTY_NAME" /etc/os-release | cut -d'"' -f2)
printf "%-25s %-15s\n" "SISTEMA OPERACIONAL:" "$OS_VERSION"
printf "%-25s ${GREEN}%-15s${RESET}\n" "UPTIME:" "$UPTIME_ALIVE"

echo -e "\n${CYAN}MEMÓRIA E SWAP:${RESET}"
free -h | awk 'NR==1{printf "%-15s %-10s %-10s %-10s\n", "TIPO", "TOTAL", "USADO", "LIVRE"} NR==2{printf "%-15s %-10s %-10s %-10s\n", "RAM", $2, $3, $7}'
swapon --show=NAME,SIZE,USED,PRIO | awk 'NR>1{printf "%-15s %-10s %-10s (PRIO: %s)\n", $1, $2, $3, $4}'

echo -e "\n${CYAN}SEGURANÇA E FIREWALL:${RESET}"
SSH_STATUS=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
[ "$SSH_STATUS" == "no" ] && STATUS_SSH="${GREEN}PROTEGIDO (CHAVE)${RESET}" || STATUS_SSH="${RED}SENHA ATIVA${RESET}"
printf "%-25s %-15s\n" "AUTENTICAÇÃO SSH:" "$STATUS_SSH"

if command -v iptables >/dev/null; then
    printf "%-25s ${GREEN}%-15s${RESET}\n" "IPTABLES-PERSISTENT:" "INSTALADO"
fi

echo -e "\n${CYAN}DOCKER E GIT:${RESET}"
if command -v docker >/dev/null; then
    DOCKER_V=$(docker version --format '{{.Server.Version}}')
    echo -e "Docker Engine: ${GREEN}v$DOCKER_V${RESET}"
else
    echo -e "Docker Engine: ${RED}NÃO INSTALADO${RESET}"
fi

if command -v git >/dev/null; then
    GIT_NAME=$(git config --global user.name || echo "Não configurado")
    echo -e "Git Configurado para: ${GREEN}$GIT_NAME${RESET}"
fi

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${GREEN}             SISTEMA PRONTO E OTIMIZADO!${RESET}"
echo -e "${CYAN}================================================================${RESET}"
