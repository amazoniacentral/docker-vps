# --- FASE 9: LOG DE MONITORAMENTO FINAL (RAIO-X COMPLETO) ---
echo "=============================================================================="
echo " O QUE ESTE SCRIPT FAZ:"
echo " 1. Resumo Global das Fases Anteriores:"
echo "    - Fases 1 & 2: Sincronização de relógio, ZRAM (zstd) e Swapfile de 6GB."
echo "    - Fases 3 & 4: Fail2Ban ativado e Docker Engine instalado e limpo."
echo "    - Fases 5 & 6: Firewall inteligente via IPTables (cadeia DOCKER-USER)."
echo "    - Fase 7: Git, GitHub CLI (gh) e autenticação obrigatória (ghcr.io)."
echo "    - Fase 8: Hardening do SSH (KeepAlive e acesso por senha mantido)."
echo " 2. Auditoria e Diagnóstico Completo (Raio-X):"
echo "    - Executa varredura profunda de hardware, memória, rede, firewalls,"
echo "      containers Docker, volumes e logs."
echo "=============================================================================="

unset DEBIAN_FRONTEND
clear
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           STATUS GERAL E HARDWARE DA VPS${RESET}"
echo -e "${CYAN}================================================================${RESET}"

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
BASE_DIR=$(readlink -f "$SCRIPT_DIR/..")

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
echo -e "${YELLOW}           SEGURANÇA E FIREWALL (UFW & IPTABLES)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# 1. Checagem do UFW
if command -v ufw >/dev/null 2>&1; then
    UFW_STATUS=$(ufw status | head -n 1 | awk '{print $2}')
    if [ "$UFW_STATUS" == "active" ]; then
        printf "%-25s ${GREEN}%-15s${RESET}\n" "UFW STATUS:" "ATIVO"
        ufw status numbered | sed 's/^/  /'
    else
        printf "%-25s ${RED}%-15s${RESET}\n" "UFW STATUS:" "INATIVO"
    fi
else
    printf "%-25s ${YELLOW}%-15s${RESET}\n" "UFW STATUS:" "NÃO INSTALADO"
fi

echo -e "---"

# 2. Checagem do IPTABLES (DOCKER-USER)
printf "%-25s " "IPTABLES (DOCKER-USER):"
if iptables -L DOCKER-USER -n >/dev/null 2>&1; then
    RULE_COUNT=$(iptables -L DOCKER-USER -n | wc -l)
    if [ "$RULE_COUNT" -gt 2 ]; then
        echo -e "${GREEN}ATIVO (PROTEGENDO DOCKER)${RESET}"
        echo -e "${CYAN}Regras DOCKER-USER:${RESET}"
        iptables -L DOCKER-USER -n --line-numbers | sed 's/^/  /'
    else
        echo -e "${YELLOW}SEM REGRAS DE FILTRO${RESET}"
    fi
else
    echo -e "${RED}CORRENTE NÃO ENCONTRADA${RESET}"
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

RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_AVAIL=$(free -m | awk '/Mem:/ {print $7}')
RAM_BUFF=$(free -m | awk '/Mem:/ {print $6}')
RAM_PERC=$(awk "BEGIN {printf \"%.2f\", (($RAM_TOTAL-$RAM_AVAIL)/$RAM_TOTAL)*100}")

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
echo -e "${GREEN}             SETUP ABSOLUTO FINALIZADO COM SUCESSO!${RESET}"
echo -e "${CYAN}================================================================${RESET}"
