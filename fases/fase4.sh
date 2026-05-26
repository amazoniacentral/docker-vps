# --- FASE 4: PERFORMANCE (ZRAM & SWAP) ---
echo "== Configurando Camadas de Memória (ZRAM + SWAP) =="

# Inicializa variáveis de controle
ZRAM_SUPORTADO=false

# 1. Limpeza agressiva e cirúrgica de resíduos travados na memória
echo "== Resetando possíveis travamentos de ZRAM anterior =="
systemctl stop zramswap 2>/dev/null || true

swapon --show=NAME --noheadings | grep "zram" | while read -r zram_dev; do
    swapoff "$zram_dev" || true
done

if [ -d /sys/class/block/zram0 ]; then
    echo 1 > /sys/class/block/zram0/reset 2>/dev/null || true
    modprobe -r zram 2>/dev/null || true
fi

# 2. Validação Real de Suporte ao Módulo ZRAM
echo "== Validando suporte a ZRAM no ambiente =="
if modprobe zram 2>/dev/null; then
    # Se o módulo carregou, tentamos startar o serviço
    cat <<EOF > /etc/default/zramswap
ALGO=zstd
PERCENT=100
PRIORITY=100
EOF
    systemctl daemon-reload
    if systemctl start zramswap 2>/dev/null; then
        echo -e "${GREEN}ZRAM ativado e iniciado com sucesso!${RESET}"
        ZRAM_SUPORTADO=true
    fi
fi

# 3. Definição dinâmica do tamanho do Swapfile baseado no suporte do sistema
if [ "$ZRAM_SUPORTADO" = true ]; then
    SWAP_SIZE="4G"
else
    echo -e "${YELLOW}Aviso: ZRAM não é permitido ou falhou nesta VPS. Ativando contingência com Swapfile expandido.${RESET}"
    SWAP_SIZE="6G"
fi

# 4. Configuração Segura do Swapfile em Disco
echo "== Configurando Swapfile (${SWAP_SIZE}) =="

# Se o arquivo físico não existe, cria do zero
if [ ! -f /swapfile ]; then
    fallocate -l $SWAP_SIZE /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=$(echo $SWAP_SIZE | sed 's/G//' | awk '{print $1 * 1024}')
    chmod 600 /swapfile
    mkswap /swapfile
else
    # Se o arquivo já existe, verifica se precisamos expandi-lo para 6GB com segurança
    CURRENT_SWAP_BYTES=$(stat -c%s /swapfile 2>/dev/null || echo 0)
    if [ "$SWAP_SIZE" = "6G" ] && [ "$CURRENT_SWAP_BYTES" -lt 5000000000 ]; then
        echo "== Expandindo Swapfile existente para 6G =="
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile
        fallocate -l 6G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=6144
        chmod 600 /swapfile
        mkswap /swapfile
    fi
fi

# Ativa o swapfile de forma segura sem estourar erro se ele já estiver ativo (busy)
swapon -p 50 /swapfile 2>/dev/null || true

# Garante a persistência limpa e sem duplicatas no fstab
sed -i '/swapfile/d' /etc/fstab
echo "/swapfile none swap sw,pri=50 0 0" >> /etc/fstab

# 5. Limpeza de outros swaps órfãos e antigos remanescentes
echo "== Removendo outros swaps órfãos =="
swapon --show=NAME --noheadings | grep -v "/swapfile" | grep -v "zram" | while read -r old_swap; do
    swapoff "$old_swap" || true
done

# 6. Ajusta parâmetros de Swappiness
echo "vm.swappiness=10" > /etc/sysctl.d/sysctl.conf
sysctl -p /etc/sysctl.d/sysctl.conf

echo -e "${GREEN}Configuração de performance finalizada com sucesso!${RESET}"
