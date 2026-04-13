#!/bin/bash

# Cores para o terminal
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

clear
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           STATUS GERAL E HARDWARE DA VPS${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# Coleta Informações do Sistema e Hardware
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
echo -e "${YELLOW}           SEGURANÇA E FIREWALL (UFW)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# Verifica Status do UFW
UFW_STATUS=$(ufw status | head -n 1 | awk '{print $2}')
if [ "$UFW_STATUS" == "active" ]; then
    printf "%-25s ${GREEN}%-15s${RESET}\n" "STATUS DO FIREWALL:" "ATIVO/PROTEGIDO"
    echo -e "${CYAN}Regras Ativas:${RESET}"
    ufw status numbered | sed 's/^/  /'
else
    printf "%-25s ${RED}%-15s${RESET}\n" "STATUS DO FIREWALL:" "DESATIVADO (PERIGO)"
fi

echo -e "\n${CYAN}Portas em Escuta (Listen):${RESET}"
printf "%-10s %-10s %-20s %-15s\n" "PROTO" "PORTA" "ENDEREÇO" "SERVIÇO"
ss -tulpn | grep LISTEN | awk '{split($5,a,":"); port=a[length(a)]; proto=$1; addr=$5; service=$7; printf "%-10s %-10s %-20s %-15s\n", proto, port, addr, service}' | sed 's/users:(("//g; s/",.*//g'

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           REDES E CONECTIVIDADE DA VPS${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# IPs Públicos
IPV4_PUB=$(curl -s4 icanhazip.com || echo "N/A")
IPV6_PUB=$(curl -s6 --connect-timeout 2 icanhazip.com || echo -e "${RED}Inativo/Sem Rota${RESET}")

printf "%-25s ${YELLOW}%-15s${RESET}\n" "IP PÚBLICO (IPv4):" "$IPV4_PUB"
printf "%-25s %-15s\n" "IP PÚBLICO (IPv6):" "$IPV6_PUB"

echo -e "\n${CYAN}Interfaces de Rede Ativas:${RESET}"
printf "%-18s %-15s %-12s %-12s %-15s\n" "INTERFACE" "IP" "RECEBIDO" "ENVIADO" "REDE DOCKER"

for dev in $(ls /sys/class/net/ | grep -v "lo"); do
    ip_addr=$(ip -4 addr show $dev | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    if [ -z "$ip_addr" ]; then ip_addr="-"; fi
    
    rx=$(cat /sys/class/net/$dev/statistics/rx_bytes 2>/dev/null || echo 0)
    tx=$(cat /sys/class/net/$dev/statistics/tx_bytes 2>/dev/null || echo 0)
    
    rx_mb=$(awk "BEGIN {printf \"%.2f MB\", $rx/1024/1024}")
    tx_mb=$(awk "BEGIN {printf \"%.2f MB\", $tx/1024/1024}")

    docker_net="-"
    if [[ $dev == br-* ]]; then
        net_id=$(echo $dev | cut -d'-' -f2)
        docker_net=$(docker network ls --filter id=$net_id --format "{{.Name}}" | head -n1)
    elif [[ $dev == "docker0" ]]; then
        docker_net="default (bridge)"
    elif [[ $dev == eth* ]]; then
        docker_net="WAN/Internet"
    elif [[ $dev == veth* ]]; then
        docker_net="veth-pair (con)"
    fi
    
    printf "%-18s %-15s %-12s %-12s %-15s\n" "$dev" "$ip_addr" "$rx_mb" "$tx_mb" "$docker_net"
done

echo -e "\n${CYAN}Redes Docker em Uso (Subnets):${RESET}"
printf "%-15s %-15s %-15s %-10s\n" "NOME" "SUBNET" "GATEWAY" "DRIVER"
docker network ls --filter "driver=bridge" --format "{{.Name}}" | while read -r net_name; do
    SUBNET=$(docker network inspect "$net_name" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "-")
    GATEWAY=$(docker network inspect "$net_name" --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "-")
    DRIVER=$(docker network inspect "$net_name" --format '{{.Driver}}')
    
    printf "%-15s %-15s %-15s %-10s\n" "$net_name" "$SUBNET" "$GATEWAY" "$DRIVER"
done

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           RECURSOS DA VPS (MEMÓRIA DO SISTEMA)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# Coleta dados da RAM
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_AVAIL=$(free -m | awk '/Mem:/ {print $7}')
RAM_BUFF=$(free -m | awk '/Mem:/ {print $6}')
RAM_PERC=$(awk "BEGIN {printf \"%.2f\", (($RAM_TOTAL-$RAM_AVAIL)/$RAM_TOTAL)*100}")

# Coleta dados do ZRAM e Swapfile
ZRAM_DATA=$(swapon --show=NAME,SIZE,USED --bytes | grep "zram0" || echo "zram0 0 0")
DISK_DATA=$(swapon --show=NAME,SIZE,USED --bytes | grep -v "zram0" | grep -v "NAME" || echo "disco 0 0")

ZRAM_TOTAL_MB=$(echo $ZRAM_DATA | awk '{printf "%.0f", $2/1024/1024}')
ZRAM_USED_MB=$(echo $ZRAM_DATA | awk '{printf "%.0f", $3/1024/1024}')
ZRAM_PERC=$(awk "BEGIN {printf \"%.2f\", ($ZRAM_TOTAL_MB > 0 ? $ZRAM_USED_MB/$ZRAM_TOTAL_MB*100 : 0)}")

DISK_TOTAL_MB=$(echo $DISK_DATA | awk '{sum+=$2} END {printf "%.0f", sum/1024/1024}')
DISK_USED_MB=$(echo $DISK_DATA | awk '{sum+=$3} END {printf "%.0f", sum/1024/1024}')
DISK_PERC=$(awk "BEGIN {printf \"%.2f\", ($DISK_TOTAL_MB > 0 ? $DISK_USED_MB/$DISK_TOTAL_MB*100 : 0)}")

printf "${CYAN}%-15s %-12s %-12s %-12s %-12s %-12s${RESET}\n" "TIPO" "TOTAL" "USADO" "LIVRE/DISP" "CACHE" "USO %"
printf "%-15s %-12s %-12s %-12s %-12s %-12s\n" "RAM (MB)" "$RAM_TOTAL" "$RAM_USED" "$RAM_AVAIL" "$RAM_BUFF" "$RAM_PERC%"
printf "%-15s %-12s %-12s %-12s %-12s %-12s\n" "ZRAM (MB)" "$ZRAM_TOTAL_MB" "$ZRAM_USED_MB" "-" "-" "$ZRAM_PERC%"
printf "%-15s %-12s %-12s %-12s %-12s %-12s\n" "SWAP (MB)" "$DISK_TOTAL_MB" "$DISK_USED_MB" "-" "-" "$DISK_PERC%"

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           DESEMPENHO DA CPU E DISCO (I/O)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
IOWAIT=$(top -bn1 | grep "Cpu(s)" | awk '{for(i=1;i<=NF;i++) if($i=="wa") print $(i-1)}' | head -n1 | tr ',' '.')
IOWAIT=${IOWAIT:-0.0}

if (( $(echo "$IOWAIT > 10.0" | bc -l 2>/dev/null || echo 0) )); then WARN_COLOR=$RED; else WARN_COLOR=$GREEN; fi

printf "%-25s %-15s\n" "LOAD AVERAGE (1, 5, 15):" "$LOAD"
echo -ne "CPU I/O WAIT (DISCO):     ${WARN_COLOR}${IOWAIT}%${RESET} (Ideal < 10%)\n"

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           ESPAÇO EM DISCO (EM GB)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

df -BG / | awk '
  NR==1 {printf "%-15s %-12s %-12s %-12s %-12s\n", "PARTIÇÃO", "TOTAL", "USADO", "DISP", "USO %"}
  NR==2 {printf "%-15s %-12s %-12s %-12s %-12s\n", "Principal (/)", $2, $3, $4, $5}
'

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           TAMANHO DOS LOGS DOS CONTAINERS${RESET}"
echo -e "${CYAN}================================================================${RESET}"

LOG_FILES=$(find /var/lib/docker/containers/ -name "*.log" -size +50M 2>/dev/null)
if [ -z "$LOG_FILES" ]; then
    echo -e "${GREEN}Todos os logs estão sob controle (< 50MB).${RESET}"
else
    printf "%-45s %-15s\n" "CONTAINER ID (LOG)" "TAMANHO"
    for log in $LOG_FILES; do
        SIZE=$(du -sh "$log" | awk '{print $1}')
        ID=$(basename $(dirname "$log") | cut -c1-12)
        printf "%-45s ${RED}%-15s${RESET}\n" "$ID" "$SIZE"
    done
fi

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           USO DE DISCO POR VOLUME (DOCKER)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

VOLUMES=$(docker volume ls -q)
if [ -z "$VOLUMES" ]; then echo -e "Nenhum volume encontrado."; else
    printf "%-40s %-15s\n" "VOLUME" "TAMANHO"
    for vol in $VOLUMES; do
        MOUNTPOINT=$(docker volume inspect --format '{{ .Mountpoint }}' "$vol")
        SIZE=$(du -sh "$MOUNTPOINT" 2>/dev/null | awk '{print $1}')
        printf "%-40s %-15s\n" "$vol" "$SIZE"
    done
fi

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           MAPEAMENTO DE IDENTIDADE E REDE (DOCKER)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

printf "%-22s %-18s %-30s %-12s %-25s\n" "NOME" "HOSTNAME" "IP INTERNO" "STATUS" "REDES"

for cid in $(docker ps -q); do
    NAME=$(docker inspect -f '{{.Name}}' $cid | sed 's/\///')
    HOST=$(docker inspect -f '{{.Config.Hostname}}' $cid)
    STAT=$(docker inspect -f '{{.State.Status}}' $cid)
    
    IPS=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}, {{end}}' $cid | sed 's/, $//')
    NETS=$(docker inspect -f '{{range $p, $conf := .NetworkSettings.Networks}}{{$p}}, {{end}}' $cid | sed 's/, $//')

    printf "%-22s %-18s %-30s %-12s %-25s\n" "$NAME" "$HOST" "$IPS" "$STAT" "$NETS"
done

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           CONSUMO DOS CONTAINERS (DOCKER)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}\t{{.PIDs}}"

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           CERTIFICADOS SSL E SAÚDE${RESET}"
echo -e "${CYAN}================================================================${RESET}"

ACME_FILE="/opt/fsilva-cloud/proxy/acme.json"

if [ -f "$ACME_FILE" ]; then
    CERT_COUNT=$(grep -o '"certificate":' "$ACME_FILE" | wc -l)
    PERM=$(stat -c "%a" "$ACME_FILE")
    printf "%-25s %-15s\n" "CERTIFICADOS ATIVOS:" "$CERT_COUNT"
    printf "%-25s %-15s\n" "PERMISSÃO ACME.JSON:" "$PERM (Ideal 600)"
    
    echo -e "\n${CYAN}Domínios com SSL Ativo:${RESET}"
    if command -v jq >/dev/null 2>&1; then
        jq -r '..|.main? // empty' "$ACME_FILE" 2>/dev/null | sort -u | sed 's/^/ - /'
    else
        grep -Po '(?<="main": ")[^"]*' "$ACME_FILE" | sort -u | sed 's/^/ - /'
    fi
else
    printf "%-25s ${RED}%-15s${RESET}\n" "ACME.JSON:" "Não encontrado"
fi

echo -e ""
INODES=$(df -i / | awk 'NR==2 {print $5}')
CONNS=$(ss -ant | grep -E ':80|:443' | wc -l)
CRASHING=$(docker ps -a | grep -c "restarting")

printf "%-25s %-15s\n" "INODES EM USO (/):" "$INODES"
printf "%-25s %-15s\n" "CONEXÕES WEB (80/443):" "$CONNS"
printf "%-25s %-15s\n" "CONTAINERS EM ERRO:" "$CRASHING"

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           CONEXÕES DO BANCO DE DADOS (POSTGRES)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

DB_CONTAINER="postgres"
if [ "$(docker ps -q -f name=$DB_CONTAINER)" ]; then
    DB_USER=$(docker exec $DB_CONTAINER env | grep POSTGRES_USER | cut -d'=' -f2)
    DB_USER=${DB_USER:-postgres}
    DB_NAME=$(docker exec $DB_CONTAINER env | grep POSTGRES_DB | cut -d'=' -f2)
    DB_NAME=${DB_NAME:-$DB_USER}
    DB_STATS=$(docker exec --user postgres $DB_CONTAINER psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT state, count(*) FROM pg_stat_activity GROUP BY state;" 2>/dev/null | grep .)
    if [ $? -eq 0 ] && [ ! -z "$DB_STATS" ]; then
        printf "%-25s %-15s\n" "STATUS" "QUANTIDADE"
        echo "$DB_STATS" | awk -F'|' '{status=($1==" " || $1=="" ? "Interno/System" : $1); gsub(/^[ \t]+|[ \t]+$/, "", status); printf "%-25s %-15s\n", status, $2}'
        TOTAL_CONNS=$(echo "$DB_STATS" | awk -F'|' '{sum+=$2} END {print sum}')
        echo -e "${CYAN}----------------------------------------------------------------${RESET}"
        printf "%-25s ${YELLOW}%-15s${RESET}\n" "TOTAL OCUPADO:" "$TOTAL_CONNS / 200"
    else
        echo -e "${RED}ERRO: Dados do Postgres inacessíveis.${RESET}"
    fi
fi

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${YELLOW}       ITENS REALMENTE ÓRFÃOS (LIXO)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

STOPPED_CONS=$(docker ps -a -f status=exited -f status=created --format " - {{.Names}}")
echo -ne "${CYAN}Containers Parados:${RESET}"; if [ -z "$STOPPED_CONS" ]; then echo " Nenhum"; else echo -e "\n$STOPPED_CONS"; fi
DANGLING_IMGS=$(docker images -f "dangling=true" --format " - {{.ID}} ({{.Size}})")
echo -ne "${CYAN}Imagens Órfãs (<none>):${RESET}"; if [ -z "$DANGLING_IMGS" ]; then echo " Nenhuma"; else echo -e "\n$DANGLING_IMGS"; fi
CACHE_RECLAIM=$(docker system df --format "{{.Type}};{{.Reclaimable}}" | grep "Build Cache" | cut -d';' -f2)
echo -ne "${CYAN}Build Cache Acumulado:${RESET} "; if [[ "$CACHE_RECLAIM" == "0B" ]] || [[ "$CACHE_RECLAIM" == "" ]]; then echo "Limpo"; else echo -e "${RED}$CACHE_RECLAIM${RESET}"; fi

echo -e "\n${YELLOW}DICAS DE LIMPEZA:${RESET}"
echo -e "1. Limpar Tudo: ${CYAN}docker system prune -f${RESET}"
echo -e "2. Limpar Cache: ${CYAN}docker builder prune -f${RESET}"
echo -e "${CYAN}================================================================${RESET}"
