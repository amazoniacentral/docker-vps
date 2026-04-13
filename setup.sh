#!/bin/bash
set -e

# =================================================================
# SCRIPT DE SETUP E MONITORAMENTO INTEGRADO - FSilva Cloud
# =================================================================

# 1. Verificar se é root
if [ "$EUID" -ne 0 ]; then 
  echo "Erro: Execute este script como root."
  exit 1
fi

# Definição de Cores
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

clear
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           INICIANDO SETUP E OTIMIZAÇÃO DA VPS${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# --- FASE 1: DEPENDÊNCIAS DE SISTEMA ---
echo "== Instalando utilitários essenciais (psmisc, util-linux, net-tools) =="
apt-get update
apt-get install -y psmisc util-linux procps sed grep coreutils curl jq bc

# --- FASE 2: DESBLOQUEIO E LIMPEZA ---
echo "== Verificando travas de processos (APT/DPKG) =="
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
apt-get install -y netfilter-persistent iptables-persistent \
  ca-certificates gnupg lsb-release htop unzip zram-tools htpdate fail2ban tree git

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
fi

# --- FASE 7: SEGURANÇA SSH ---
echo -e "\n${YELLOW}Deseja BLOQUEAR acesso por senha no SSH? (s/n)${RESET}"
read -p "> " CONFIRM_SSH < /dev/tty
if [[ "$CONFIRM_SSH" =~ ^[Ss]$ ]]; then
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart ssh
fi

# --- FASE 8: MONITORAMENTO INTEGRADO NO LOG FINAL ---
unset DEBIAN_FRONTEND
clear
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           STATUS GERAL E HARDWARE DA VPS (PÓS-SETUP)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

UPTIME_ALIVE=$(uptime -p | sed 's/up //')
OS_VERSION=$(grep "PRETTY_NAME" /etc/os-release | cut -d'"' -f2)
CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
CURRENT_DATE=$(date "+%d/%m/%Y %H:%M:%S")

echo -e "SISTEMA:                  $OS_VERSION"
echo -e "MODELO CPU:               $CPU_MODEL"
echo -e "TEMPO DE VIDA (UP):       ${GREEN}$UPTIME_ALIVE${RESET}"
echo -e "DATA/HORA ATUAL:          $CURRENT_DATE"

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           REDES E CONECTIVIDADE DA VPS${RESET}"
echo -e "${CYAN}================================================================${RESET}"

IPV4_PUB=$(curl -s4 icanhazip.com || echo "N/A")
printf "%-25s ${YELLOW}%-15s${RESET}\n" "IP PÚBLICO (IPv4):" "$IPV4_PUB"

echo -e "\nInterfaces de Rede e Docker:"
printf "%-18s %-15s %-15s\n" "INTERFACE" "IP" "REDE DOCKER"
for dev in $(ls /sys/class/net/ | grep -v "lo"); do
    ip_addr=$(ip -4 addr show $dev | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1 || echo "-")
    docker_net="-"
    if [[ $dev == br-* ]]; then
        net_id=$(echo $dev | cut -d'-' -f2)
        docker_net=$(docker network ls --filter id=$net_id --format "{{.Name}}" | head -n1)
    elif [[ $dev == "docker0" ]]; then docker_net="bridge (def)"
    elif [[ $dev == eth* ]]; then docker_net="WAN"
    fi
    printf "%-18s %-15s %-15s\n" "$dev" "$ip_addr" "$docker_net"
done

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           RECURSOS (MEMÓRIA, I/O E DISCO)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_AVAIL=$(free -m | awk '/Mem:/ {print $7}')
RAM_PERC=$(awk "BEGIN {printf \"%.2f\", (($RAM_TOTAL-$RAM_AVAIL)/$RAM_TOTAL)*100}")
IOWAIT=$(top -bn1 | grep "Cpu(s)" | awk '{for(i=1;i<=NF;i++) if($i=="wa") print $(i-1)}' | head -n1 | tr ',' '.')

printf "%-25s %-15s\n" "RAM USO %:" "$RAM_PERC%"
echo -ne "CPU I/O WAIT (DISCO):     ${YELLOW}${IOWAIT}%${RESET}\n"
df -h / | awk 'NR==2 {printf "ESPAÇO EM DISCO (/):      %s usado (%s disp)\n", $5, $4}'

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           MAPEAMENTO DE CONTAINERS E VOLUMES${RESET}"
echo -e "${CYAN}================================================================${RESET}"

if docker ps -a >/dev/null 2>&1; then
    printf "%-22s %-15s %-12s %-25s\n" "NOME" "IP INTERNO" "STATUS" "REDES"
    for cid in $(docker ps -q); do
        NAME=$(docker inspect -f '{{.Name}}' $cid | sed 's/\///')
        STAT=$(docker inspect -f '{{.State.Status}}' $cid)
        IPS=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' $cid)
        NETS=$(docker inspect -f '{{range $p, $conf := .NetworkSettings.Networks}}{{$p}} {{end}}' $cid)
        printf "%-22s %-15s %-12s %-25s\n" "$NAME" "${IPS%% *}" "$STAT" "${NETS%% *}"
    done
    
    echo -e "\n${CYAN}Uso de Disco por Volumes:${RESET}"
    docker volume ls -q | head -n 5 | while read vol; do
        MOUNT=$(docker volume inspect --format '{{ .Mountpoint }}' "$vol")
        SIZE=$(du -sh "$MOUNT" 2>/dev/null | awk '{print $1}' || echo "N/A")
        printf " - %-35s %-10s\n" "$vol" "$SIZE"
    done
else
    echo -e "${RED}Docker não está rodando ou nenhum container ativo.${RESET}"
fi

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           SEGURANÇA, SSL E SAÚDE${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# Verificação SSH
if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    echo -e "AUTENTICAÇÃO SSH:         ${GREEN}PROTEGIDO (SOMENTE CHAVE)${RESET}"
else
    echo -e "AUTENTICAÇÃO SSH:         ${RED}SENHA ATIVA (VULNERÁVEL)${RESET}"
fi

# ACME / SSL
ACME_FILE="/opt/fsilva-cloud/proxy/acme.json"
if [ -f "$ACME_FILE" ]; then
    CERT_COUNT=$(grep -o '"certificate":' "$ACME_FILE" | wc -l)
    echo -e "CERTIFICADOS SSL:         ${GREEN}$CERT_COUNT Ativos${RESET}"
else
    echo -e "ACME.JSON:                ${YELLOW}Não encontrado${RESET}"
fi

CRASHING=$(docker ps -a | grep -c "restarting" || echo 0)
echo -e "CONTAINERS EM ERRO:       ${RED}$CRASHING${RESET}"

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${GREEN}             SETUP E MONITORAMENTO FINALIZADOS!${RESET}"
echo -e "${CYAN}================================================================${RESET}"
