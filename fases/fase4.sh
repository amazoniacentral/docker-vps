# --- FASE 4: PERFORMANCE (ZRAM & SWAP) ---
echo "== Configurando Camadas de Memória (ZRAM + SWAP) =="

# Inicializa variáveis de controle
ZRAM_SUPORTADO=false

# 1. Verifica se o Kernel e a Virtualização permitem ZRAM
echo "== Validando suporte a ZRAM no ambiente =="
systemctl stop zramswap 2>/dev/null || true

# Limpa resíduos anteriores se existirem
if [ -d /sys/class/block/zram0 ]; then
    echo 1 > /sys/class/block/zram0/reset 2>/dev/null || true
    modprobe -r zram 2>/dev/null || true
fi

# Teste real de injeção do módulo
if modprobe zram 2>/dev/null; then
    ZRAM_SUPORTADO=true
fi

# 2. Configura ZRAM apenas se for permitido pelo Host/Kernel
if [ "$ZRAM_SUPORTADO" = true ]; then
    echo -e "${GREEN}Suporte a ZRAM detectado. Ativando memória comprimida...${RESET}"
    cat <<EOF > /etc/default/zramswap
ALGO=zstd
PERCENT=100
PRIORITY=100
EOF
    systemctl start zramswap 2>/dev/null || ZRAM_SUPORTADO=false
fi

# Define o tamanho do Swapfile baseado no suporte a ZRAM
if [ "$ZRAM_SUPORTADO" = true ]; then
    SWAP_SIZE="4G"
else
    echo -e "${YELLOW}Aviso: ZRAM não é permitido nesta VPS (LXC/Kernel capado). Compensando com Swapfile expandido.${RESET}"
    SWAP_SIZE="6G"
fi

# 3. Configura SWAP em Disco inteligente
echo "== Configurando Swapfile (${SWAP_SIZE}) =="

# Se o arquivo já existir mas o tamanho atual for menor do que o planejado (ex: mudou de 4G para 6G), recria do zero
if [ -f /swapfile ]; then
    CURRENT_SWAP_BYTES=$(stat -c%s /swapfile 2>/dev/null || echo 0)
    if [ "$SWAP_SIZE" = "6G" ] && [ "$CURRENT_SWAP_BYTES" -lt 5000000000 ]; then
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile
    fi
fi

if [ ! -f /swapfile ]; then
    fallocate -l $SWAP_SIZE /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=$(echo $SWAP_SIZE | sed 's/G//' | awk '{print $1 * 1024}')
    chmod 600 /swapfile
    mkswap /swapfile
fi

# Garante a persistência limpa no fstab
sed -i '/swapfile/d' /etc/fstab
echo "/swapfile none swap sw,pri=50 0 0" >> /etc/fstab

# Ativa o swapfile imediatamente
swapon -p 50 /swapfile || true

# 4. Limpeza segura de outros swaps órfãos e antigos
echo "== Removendo swaps órfãos antigos =="
swapon --show=NAME --noheadings | grep -v "/swapfile" | grep -v "zram" | while read -r old_swap; do
    swapoff "$old_swap" || true
done

# 5. Ajusta parâmetros de Swappiness
echo "vm.swappiness=10" > /etc/sysctl.d/sysctl.conf
sysctl -p /etc/sysctl.d/sysctl.conf

echo -e "${GREEN}Configuração de performance finalizada com sucesso!${RESET}"
