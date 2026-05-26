# --- FASE 4: PERFORMANCE (ZRAM & SWAP) ---
echo "== Configurando Camadas de Memória (ZRAM + SWAP) =="

# 1. Configura ZRAM primeiro (Prioridade 100) para dar fôlego ao sistema antes do swapoff
cat <<EOF > /etc/default/zramswap
ALGO=zstd
PERCENT=100
PRIORITY=100
EOF

# Tenta reiniciar o zramswap (se falhar, força o carregamento do módulo)
systemctl restart zramswap || (modprobe zram && systemctl restart zramswap)

# 2. Configura SWAP em Disco de 4GB (Prioridade 50)
if [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
  chmod 600 /swapfile
  mkswap /swapfile
fi

# Garante que o fstab tenha apenas o nosso swapfile
sed -i '/swap/d' /etc/fstab
echo "/swapfile none swap sw,pri=50 0 0" >> /etc/fstab

# Ativa o novo swapfile em disco imediatamente com prioridade menor
swapon -p 50 /swapfile || true

# 3. Agora remove os swaps antigos com segurança (o sistema usará o novo se precisar)
# Remove apenas swaps que não sejam o nosso swapfile oficial ou o zram
swapon --show=NAME --noheadings | grep -v "/swapfile" | grep -v "zram" | while read -r old_swap; do
    swapoff "$old_swap" || true
done

# 4. Ajusta Swappiness para 10 (Evita uso prematuro do swap em disco)
echo "vm.swappiness=10" > /etc/sysctl.d/sysctl.conf
sysctl -p /etc/sysctl.d/sysctl.conf
