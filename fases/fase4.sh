# --- FASE 4: PERFORMANCE (ZRAM & SWAP) ---
echo "== Configurando Camadas de Memória (ZRAM + SWAP) =="

# Inicializa variáveis de controle
ZRAM_ATIVO=false

# 1. Tenta configurar e carregar o ZRAM
echo "== Testando suporte a ZRAM no Kernel =="
cat <<EOF > /etc/default/zramswap
ALGO=zstd
PERCENT=100
PRIORITY=100
EOF

if modprobe zram 2>/dev/null; then
    if systemctl restart zramswap 2>/dev/null; then
        echo -e "${GREEN}ZRAM ativado com sucesso!${RESET}"
        ZRAM_ATIVO=true
    fi
fi

if [ "$ZRAM_ATIVO" = false ]; then
    echo -e "${YELLOW}Aviso: Kernel da VPS não suporta ZRAM. Compensando com Swapfile expandido.${RESET}"
    # Se não tem ZRAM, aumentamos o Swap em disco para dar mais segurança
    SWAP_SIZE="6G"
else
    SWAP_SIZE="4G"
fi

# 2. Configura SWAP em Disco
echo "== Configurando Swapfile (${SWAP_SIZE}) =="
if [ -f /swapfile ]; then
    # Se o tamanho existente for diferente do planejado, remove para recriar
    CURRENT_SWAP_BYTES=$(stat -c%s /swapfile 2>/dev/null || echo 0)
    # 4G = 4294967296 bytes, 6G = 6442450944 bytes
    if [ "$SWAP_SIZE" = "6G" ] && [ "$CURRENT_SWAP_BYTES" -lt 6000000000 ]; then
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile
    fi
fi

if [ ! -f /swapfile ]; then
    fallocate -l $SWAP_SIZE /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=$(echo $SWAP_SIZE | sed 's/G//' | awk '{print $1 * 1024}')
    chmod 600 /swapfile
    mkswap /swapfile
fi

# Garante que o fstab tenha apenas o nosso swapfile limpo
sed -i '/swapfile/d' /etc/fstab
echo "/swapfile none swap sw,pri=50 0 0" >> /etc/fstab

# Ativa o swapfile imediatamente
swapon -p 50 /swapfile || true

# 3. Limpeza segura de swaps antigos e órfãos
echo "== Limpando swaps antigos =="
swapon --show=NAME --noheadings | grep -v "/swapfile" | grep -v "zram" | while read -r old_swap; do
    swapoff "$old_swap" || true
done

# 4. Ajusta parâmetros de Swappiness do sistema
echo "vm.swappiness=10" > /etc/sysctl.d/sysctl.conf
sysctl -p /etc/sysctl.d/sysctl.conf
