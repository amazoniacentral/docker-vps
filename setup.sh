#!/bin/bash
set -e

# =================================================================
# SCRIPT DE SETUP E CONFIGURAÇÃO COMPLETA - FSilva Cloud
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
echo -e "${YELLOW}           INICIANDO SETUP E OTIMIZAÇÃO DA VPS${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# --- FASE 1: INSTALAÇÃO IMEDIATA DE DEPENDÊNCIAS DE COMANDO ---
echo "== Instalando utilitários essenciais (psmisc, util-linux) =="
apt-get update
apt-get install -y psmisc util-linux procps sed grep coreutils

# --- FASE 2: DESBLOQUEIO E LIMPEZA ---
echo "== Verificando travas de processos (APT/DPKG) =="
# Agora o fuser existe e vai rodar
fuser -vki /var/lib/dpkg/lock-frontend || true
fuser -vki /var/lib/apt/lists/lock || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
dpkg --configure -a

# --- FASE 3: INSTALAÇÃO SILENCIOSA ---
echo "== Configurando ambiente não-interativo =="
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections

export DEBIAN_FRONTEND=noninteractive

echo "== Atualizando Repositórios e Sistema =="
apt-get upgrade -y

echo "== Instalando pacotes base =="
# lscpu já foi instalado pelo util-linux acima
apt-get install -y netfilter-persistent iptables-persistent \
  ca-certificates curl gnupg lsb-release htop unzip zram-tools htpdate fail2ban tree bc jq git

# Ajustar Relógio
timedatectl set-timezone America/Sao_Paulo
htpdate -s -t google.com

# --- FASE 4: PERFORMANCE (ZRAM & SWAP) ---
echo "== Configurando ZRAM (Camada 1: 50% RAM) =="
cat <<EOF > /etc/default/zramswap
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
systemctl restart zramswap

echo "== Configurando Swapfile (Camada 2: 4GB Disco) =="
if [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
  chmod 600 /swapfile
  mkswap /swapfile
fi
sed -i '/\/swapfile/d' /etc/fstab
echo "/swapfile none swap sw,pri=10 0 0" >> /etc/fstab
swapon -p 10 /swapfile || true

echo "== Otimizando Kernel (Swappiness) =="
sed -i '/vm.swappiness/d' /etc/sysctl.conf
echo "vm.swappiness=10" >> /etc/sysctl.conf
sysctl -p

# --- FASE 5: DOCKER V27 ---
echo -e "\n${YELLOW}Deseja instalar o Docker Engine v27? (s/n)${RESET}"
read -p "> " INSTALL_DOCKER < /dev/tty
if [[ "$INSTALL_DOCKER" =~ ^[Ss]$ ]]; then
    echo "== Configurando Repositório Docker =="
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    echo "== Instalando Docker v27.3.1 =="
    apt-get install -y --allow-downgrades \
      docker-ce=5:27.3.1-1~debian.12~bookworm \
      docker-ce-cli=5:27.3.1-1~debian.12~bookworm \
      containerd.io docker-buildx-plugin docker-compose-plugin
    apt-mark hold docker-ce docker-ce-cli
    systemctl enable --now docker
fi

# --- FASE 6: CONFIGURAÇÃO GIT ---
echo -e "\n${YELLOW}Deseja configurar o Git agora? (s/n)${RESET}"
read -p "> " CONFIRM_GIT < /dev/tty
if [[ "$CONFIRM_GIT" =~ ^[Ss]$ ]]; then
    echo -n "Digite o Nome de Usuário Git: "
    read -r GIT_USER < /dev/tty
    echo -n "Digite o E-mail do Git: "
    read -r GIT_EMAIL < /dev/tty
    
    git config --global user.name "$GIT_USER"
    git config --global user.email "$GIT_EMAIL"
    git config --global --add safe.directory '*'
    echo -e "${GREEN}Git configurado para $GIT_USER ($GIT_EMAIL).${RESET}"
fi

# --- FASE 7: SEGURANÇA SSH ---
echo -e "\n${YELLOW}Deseja BLOQUEAR acesso por senha no SSH? (s/n)${RESET}"
echo -e "${RED}AVISO: Tenha sua chave pública no authorized_keys antes!${RESET}"
read -p "> " CONFIRM_SSH < /dev/tty
if [[ "$CONFIRM_SSH" =~ ^[Ss]$ ]]; then
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart ssh
    echo -e "${GREEN}Acesso por senha desativado.${RESET}"
fi

# --- FASE 8: LOG FINAL (MODELO FSilva) ---
unset DEBIAN_FRONTEND
clear
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           STATUS GERAL DA VPS (PÓS-CONFIGURAÇÃO)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# Coleta de Dados
UPTIME_ALIVE=$(uptime -p | sed 's/up //')
OS_VERSION=$(grep "PRETTY_NAME" /etc/os-release | cut -d'"' -f2)
KERNEL=$(uname -r)
CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
PKGS=$(dpkg -l | grep -c "^ii")
CURRENT_DATE=$(date "+%d/%m/%Y %H:%M:%S")

printf "%-25s %-15s\n" "SISTEMA OPERACIONAL:" "$OS_VERSION"
printf "%-25s %-15s\n" "KERNEL:" "$KERNEL"
printf "%-25s %-15s\n" "MODELO CPU:" "$CPU_MODEL"
printf "%-25s %-15s\n" "PACOTES INSTALADOS:" "$PKGS"
printf "%-25s ${GREEN}%-15s${RESET}\n" "TEMPO DE VIDA (UP):" "$UPTIME_ALIVE"
printf "%-25s %-15s\n" "DATA/HORA ATUAL:" "$CURRENT_DATE"

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           RECURSOS DA VPS (MEMÓRIA E SWAP)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_AVAIL=$(free -m | awk '/Mem:/ {print $7}')
RAM_PERC=$(awk "BEGIN {printf \"%.2f\", (($RAM_TOTAL-$RAM_AVAIL)/$RAM_TOTAL)*100}")

ZRAM_DATA=$(swapon --show=NAME,SIZE,USED --bytes | grep "zram0" || echo "zram0 0 0")
ZRAM_TOTAL_MB=$(echo $ZRAM_DATA | awk '{printf "%.0f", $2/1024/1024}')

DISK_SWAP=$(swapon --show=NAME,SIZE,USED --bytes | grep "/swapfile" || echo "swapfile 0 0")
DISK_TOTAL_MB=$(echo $DISK_SWAP | awk '{printf "%.0f", $2/1024/1024}')

printf "${CYAN}%-15s %-12s %-12s %-12s${RESET}\n" "TIPO" "TOTAL" "DISPONÍVEL" "USO %"
printf "%-15s %-12s %-12s %-12s\n" "RAM (MB)" "$RAM_TOTAL" "$RAM_AVAIL" "$RAM_PERC%"
printf "%-15s %-12s %-12s %-12s\n" "ZRAM (MB)" "$ZRAM_TOTAL_MB" "-" "Ativo"
printf "%-15s %-12s %-12s %-12s\n" "SWAP (MB)" "$DISK_TOTAL_MB" "-" "Ativo"

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           SEGURANÇA E SERVIÇOS CRÍTICOS${RESET}"
echo -e "${CYAN}================================================================${RESET}"

if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    STATUS_SSH="${GREEN}PROTEGIDO (SOMENTE CHAVE)${RESET}"
else
    STATUS_SSH="${RED}SENHA ATIVA (VULNERÁVEL)${RESET}"
fi

D_VER=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "N/A")
G_NAME=$(git config --global user.name || echo "N/A")

printf "%-25s %-15s\n" "AUTENTICAÇÃO SSH:" "$STATUS_SSH"
printf "%-25s ${GREEN}%-15s${RESET}\n" "IPTABLES-PERSISTENT:" "INSTALADO"
printf "%-25s ${GREEN}v%-14s${RESET}\n" "DOCKER ENGINE:" "$D_VER"
printf "%-25s ${GREEN}%-15s${RESET}\n" "USUÁRIO GIT:" "$G_NAME"

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${GREEN}             SETUP FINALIZADO COM SUCESSO!${RESET}"
echo -e "${CYAN}================================================================${RESET}"
