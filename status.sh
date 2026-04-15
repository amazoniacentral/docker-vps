#!/bin/bash
set -e

# =================================================================
# STATUS ABSOLUTO, FIREWALL E MONITORAMENTO - FSilva Cloud
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


unset DEBIAN_FRONTEND
clear
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           STATUS GERAL E HARDWARE DA VPS${RESET}"
echo -e "${CYAN}================================================================${RESET}"

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
echo -e "${YELLOW}           IDENTIDADE E SEGURANÇA (GIT & SSH)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    printf "%-25s ${GREEN}%-15s${RESET}\n" "AUTENTICAÇÃO SSH:" "CHAVE (OK)"
else
    printf "%-25s ${RED}%-15s${RESET}\n" "AUTENTICAÇÃO SSH:" "SENHA (VULNERÁVEL)"
fi

G_USER=$(git config --global user.name || echo "N/A")
G_MAIL=$(git config --global user.email || echo "N/A")
printf "%-25s ${CYAN}%-15s${RESET}\n" "USUÁRIO GIT:" "$G_USER"
printf "%-25s ${CYAN}%-15s${RESET}\n" "E-MAIL GIT:" "$G_MAIL"

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           FIREWALL E REDE (IPTABLES DOCKER-USER)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

printf "%-25s " "IPTABLES (DOCKER-USER):"
if iptables -L DOCKER-USER -n >/dev/null 2>&1; then
    RULE_COUNT=$(iptables -L DOCKER-USER -n | wc -l)
    if [ "$RULE_COUNT" -gt 2 ]; then
        echo -e "${GREEN}ATIVO (PROTEGENDO DOCKER)${RESET}"
        iptables -L DOCKER-USER -n --line-numbers | sed 's/^/  /'
    else
        echo -e "${YELLOW}SEM REGRAS DE FILTRO${RESET}"
    fi
else
    echo -e "${RED}CORRENTE NÃO ENCONTRADA${RESET}"
fi

IPV4_PUB=$(curl -s4 icanhazip.com || echo "N/A")
printf "\n%-25s ${YELLOW}%-15s${RESET}\n" "IP PÚBLICO (IPv4):" "$IPV4_PUB"

echo -e "\n${CYAN}Interfaces e Redes Docker:${RESET}"
printf "%-18s %-15s %-12s %-12s %-15s\n" "INTERFACE" "IP" "RECEBIDO" "ENVIADO" "DOCKER NET"
for dev in $(ls /sys/class/net/ | grep -v "lo"); do
    ip_addr=$(ip -4 addr show $dev | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1 || echo "-")
    rx=$(cat /sys/class/net/$dev/statistics/rx_bytes 2>/dev/null || echo 0)
    tx=$(cat /sys/class/net/$dev/statistics/tx_bytes 2>/dev/null || echo 0)
    rx_mb=$(awk "BEGIN {printf \"%.2f MB\", $rx/1024/1024}")
    tx_mb=$(awk "BEGIN {printf \"%.2f MB\", $tx/1024/1024}")
    
    docker_net="-"
    [[ $dev == br-* ]] && docker_net=$(docker network ls --filter id=${dev#br-} --format "{{.Name}}")
    [[ $dev == "docker0" ]] && docker_net="bridge"
    [[ $dev == eth* ]] && docker_net="Internet/WAN"
    
    printf "%-18s %-15s %-12s %-12s %-15s\n" "$dev" "$ip_addr" "$rx_mb" "$tx_mb" "$docker_net"
done

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           RECURSOS DA VPS (MEMÓRIA E DISCO)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# RAM
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_AVAIL=$(free -m | awk '/Mem:/ {print $7}')
RAM_PERC=$(awk "BEGIN {printf \"%.2f\", (($RAM_TOTAL-$RAM_AVAIL)/$RAM_TOTAL)*100}")

# ZRAM
ZRAM_DATA=$(swapon --show=NAME,SIZE,USED --bytes | grep "zram0" || echo "zram0 0 0")
ZRAM_SIZE_B=$(echo $ZRAM_DATA | awk '{print $2}')
ZRAM_USED_B=$(echo $ZRAM_DATA | awk '{print $3}')
ZRAM_TOTAL_MB=$(awk "BEGIN {printf \"%.0f\", $ZRAM_SIZE_B/1024/1024}")
ZRAM_PERC="0.00"
[ "$ZRAM_SIZE_B" -gt 0 ] && ZRAM_PERC=$(awk "BEGIN {printf \"%.2f\", ($ZRAM_USED_B/$ZRAM_SIZE_B)*100}")

# SWAP DISCO
DISK_SWAP_DATA=$(swapon --show=NAME,SIZE,USED --bytes | grep -v "zram0" | grep -v "NAME" || echo "disco 0 0")
DSWAP_SIZE_B=$(echo $DISK_SWAP_DATA | awk '{sum+=$2} END {print sum}')
DSWAP_USED_B=$(echo $DISK_SWAP_DATA | awk '{sum+=$3} END {print sum}')
DSWAP_TOTAL_MB=$(awk "BEGIN {printf \"%.0f\", $DSWAP_SIZE_B/1024/1024}")
DSWAP_PERC="0.00"
[ "$DSWAP_SIZE_B" -gt 0 ] && DSWAP_PERC=$(awk "BEGIN {printf \"%.2f\", ($DSWAP_USED_B/$DSWAP_SIZE_B)*100}")

# DISCO GERAL (/)
ROOT_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
ROOT_USED=$(df -h / | awk 'NR==2 {print $3}')
ROOT_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
ROOT_PERC=$(df -h / | awk 'NR==2 {print $5}')

printf "${CYAN}%-15s %-12s %-12s %-12s${RESET}\n" "TIPO" "TOTAL" "DISPONÍVEL" "USO %"
printf "%-15s %-12s %-12s %-12s\n" "RAM (MB)" "$RAM_TOTAL" "$RAM_AVAIL" "$RAM_PERC%"
printf "%-15s %-12s %-12s %-12s\n" "ZRAM (MB)" "$ZRAM_TOTAL_MB" "-" "$ZRAM_PERC%"
printf "%-15s %-12s %-12s %-12s\n" "SWAP (MB)" "$DSWAP_TOTAL_MB" "-" "$DSWAP_PERC%"
printf "%-15s %-12s %-12s %-12s\n" "DISCO (/)" "$ROOT_TOTAL" "$ROOT_AVAIL" "$ROOT_PERC"

echo -e "\n${CYAN}Uso de Disco por Volume (Docker):${RESET}"
docker volume ls -q | while read vol; do
    SIZE=$(du -sh $(docker volume inspect --format '{{ .Mountpoint }}' "$vol") 2>/dev/null | awk '{print $1}')
    printf " - %-40s %-15s\n" "$vol" "$SIZE"
done

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           MAPEAMENTO E SAÚDE DOS CONTAINERS${RESET}"
echo -e "${CYAN}================================================================${RESET}"

printf "%-22s %-18s %-15s %-12s\n" "NOME" "HOSTNAME" "IP INTERNO" "STATUS"
for cid in $(docker ps -q); do
    NAME=$(docker inspect -f '{{.Name}}' $cid | sed 's/\///')
    HOST=$(docker inspect -f '{{.Config.Hostname}}' $cid)
    STAT=$(docker inspect -f '{{.State.Status}}' $cid)
    IPS=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $cid)
    printf "%-22s %-18s %-15s %-12s\n" "$NAME" "$HOST" "$IPS" "$STAT"
done

ACME_FILE="/opt/fsilva-cloud/proxy/acme.json"
if [ -f "$ACME_FILE" ]; then
    CERT_COUNT=$(grep -o '"certificate":' "$ACME_FILE" | wc -l)
    echo -e "\n${GREEN}CERTIFICADOS SSL TRAEFIK:${RESET} $CERT_COUNT Ativos"
fi

CRASHING=$(docker ps -a | grep -c "restarting")
printf "\n%-25s ${RED}%-15s${RESET}\n" "CONTAINERS EM ERRO:" "$CRASHING"

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${GREEN}             SETUP ABSOLUTO FINALIZADO COM SUCESSO!${RESET}"
echo -e "${CYAN}================================================================${RESET}"
