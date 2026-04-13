#!/bin/bash
set -e

# =================================================================
# PARTE 1: SCRIPT DE SETUP (PREPARAÇÃO)
# =================================================================

# Verificar se é root
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

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           INICIANDO PREPARAÇÃO AUTOMÁTICA DA VPS${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# --- AUTOMÁTICO (SISTEMA E MEMÓRIA) ---
echo "== Corrigindo erros de repositório anteriores =="
rm -f /etc/apt/sources.list.d/docker.list

echo "== Atualizando sistema =="
apt update && apt upgrade -y

echo "== Instalando pacotes básicos e segurança =="
apt install -y ca-certificates curl gnupg lsb-release ufw htop unzip zram-tools htpdate fail2ban tree bc iptables-persistent

# Ajustar Relógio
timedatectl set-timezone America/Sao_Paulo
htpdate -s -t google.com

echo "== Configurando ZRAM (50%) =="
cat <<EOF > /etc/default/zramswap
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
systemctl restart zramswap

echo "== Configurando Swap de Disco (4GB) =="
if [ ! -f /swapfile ]; then
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

# --- PERGUNTAS (DOCKER) ---
echo -e "\n${YELLOW}--------------------------------------------------${RESET}"
read -p "Deseja instalar o Docker v27? (s/n): " INSTALL_DOCKER < /dev/tty
if [[ "$INSTALL_DOCKER" =~ ^[Ss]$ ]]; then
    install -m 0755 -d /etc/apt/keyrings
    rm -f /etc/apt/keyrings/docker.gpg
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y --allow-downgrades docker-ce=5:27.3.1-1~debian.12~bookworm docker-ce-cli=5:27.3.1-1~debian.12~bookworm containerd.io docker-buildx-plugin docker-compose-plugin
    apt-mark hold docker-ce docker-ce-cli
    systemctl enable docker && systemctl start docker
fi

# --- PERGUNTAS (GIT) ---
echo -e "\n${YELLOW}--------------------------------------------------${RESET}"
read -p "Deseja instalar e configurar o Git? (s/n): " CONFIRM_GIT < /dev/tty
if [[ "$CONFIRM_GIT" =~ ^[Ss]$ ]]; then
    apt update && apt install -y git
    echo -n "Digite o Nome do Git: "
    read -r GIT_USER < /dev/tty
    echo -n "Digite o E-mail do Git: "
    read -r GIT_EMAIL < /dev/tty
    git config --global user.name "$GIT_USER"
    git config --global user.email "$GIT_EMAIL"
    git config --global --add safe.directory '*'
fi

# --- PERGUNTAS (SSH) ---
echo -e "\n${YELLOW}--------------------------------------------------${RESET}"
read -p "Deseja criar chave SSH e DESATIVAR SENHAS? (s/n): " CONFIRM_SSH < /dev/tty
if [[ "$CONFIRM_SSH" =~ ^[Ss]$ ]]; then
    SSH_FILE="$HOME/.ssh/id_ed25519"
    if [ ! -f "$SSH_FILE" ]; then
        ssh-keygen -t ed25519 -C "${GIT_EMAIL:-vps@fcloud}" -f "$SSH_FILE" -N ""
        eval "$(ssh-agent -s)"
        ssh-add "$SSH_FILE"
    fi
    echo "== Aplicando Proteção Extra SSH (Bloqueio de Senhas) =="
    sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart ssh
    echo "Sua Chave Pública SSH:"
    cat "${SSH_FILE}.pub"
fi

echo "== Limpeza final =="
apt autoremove -y && apt autoclean

# =================================================================
# PARTE 2: STATUS FINAL (MONITORAMENTO)
# =================================================================

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           RELATÓRIO DE STATUS PÓS-INSTALAÇÃO${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# Sistema e Uptime
UPTIME_ALIVE=$(uptime -p | sed 's/up //')
OS_VERSION=$(grep "PRETTY_NAME" /etc/os-release | cut -d'"' -f2)
printf "%-25s %-15s\n" "SISTEMA OPERACIONAL:" "$OS_VERSION"
printf "%-25s ${GREEN}%-15s${RESET}\n" "TEMPO DE VIDA (UP):" "$UPTIME_ALIVE"

echo -e "\n${CYAN}SEGURANÇA E ACESSO:${RESET}"
# Check SSH Password Auth
SSH_PASS=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
[ "$SSH_PASS" == "no" ] && SSH_LABEL="${GREEN}PROTEGIDO (Somente Chave)${RESET}" || SSH_LABEL="${RED}VULNERÁVEL (Aceita Senha)${RESET}"
printf "%-25s %-15s\n" "AUTENTICAÇÃO SSH:" "$SSH_LABEL"

# Check Firewall
UFW_STATUS=$(ufw status | head -n 1 | awk '{print $2}')
[ "$UFW_STATUS" == "active" ] && UFW_LABEL="${GREEN}ATIVO${RESET}" || UFW_LABEL="${RED}INATIVO${RESET}"
printf "%-25s %-15s\n" "STATUS UFW:" "$UFW_LABEL"

echo -e "\n${CYAN}RECURSOS DE MEMÓRIA:${RESET}"
# RAM, ZRAM e SWAP
free -h | awk 'NR==1{printf "%-15s %-10s %-10s %-10s\n", "TIPO", "TOTAL", "USADO", "LIVRE"} 
              NR==2{printf "%-15s %-10s %-10s %-10s\n", "RAM", $2, $3, $7}'
swapon --show=NAME,SIZE,USED,PRIO | awk 'NR>1{printf "%-15s %-10s %-10s (PRIO: %s)\n", $1, $2, $3, $4}'

echo -e "\n${CYAN}SOFTWARES E VERSÕES:${RESET}"
# Docker
if command -v docker >/dev/null; then
    DOCKER_V=$(docker version --format '{{.Server.Version}}')
    printf "%-25s ${GREEN}%-15s${RESET}\n" "DOCKER ENGINE:" "v$DOCKER_V"
else
    printf "%-25s ${RED}%-15s${RESET}\n" "DOCKER ENGINE:" "NÃO INSTALADO"
fi

# Git
if command -v git >/dev/null; then
    GIT_V=$(git --version | awk '{print $3}')
    printf "%-25s ${GREEN}%-15s${RESET}\n" "GIT VERSION:" "$GIT_V"
    printf "%-25s %-15s\n" "GIT USER:" "$(git config --global user.name || echo 'N/A')"
else
    printf "%-25s ${RED}%-15s${RESET}\n" "GIT:" "NÃO INSTALADO"
fi

echo -e "\n${CYAN}ARMAZENAMENTO:${RESET}"
df -h / | awk 'NR==2{printf "Espaço em Disco: %s ocupado de %s (%s livre)\n", $3, $2, $4}'

echo -e "${CYAN}================================================================${RESET}"
echo -e "${GREEN}             PROCESSAMENTO CONCLUÍDO COM SUCESSO!${RESET}"
echo -e "${CYAN}================================================================${RESET}"
