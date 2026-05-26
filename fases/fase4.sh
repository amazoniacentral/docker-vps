# --- FASE 4: PERFORMANCE (ZRAM & SWAP) ---
echo "== Configurando Camadas de Memória (ZRAM + SWAP) =="

# 1. Desativa TODOS os swaps atuais para limpar lixo de 1GB
swapoff -a || true

# 2. Configura ZRAM (Prioridade 100)
cat <<EOF > /etc/default/zramswap
ALGO=zstd
PERCENT=100
PRIORITY=100
EOF
systemctl restart zramswap

# 3. Configura SWAP em Disco de 4GB (Prioridade 50)
if [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
  chmod 600 /swapfile
  mkswap /swapfile
fi

# Garante que o fstab tenha apenas o nosso swapfile
sed -i '/swap/d' /etc/fstab
echo "/swapfile none swap sw,pri=50 0 0" >> /etc/fstab

# Ativa o nosso swapfile manualmente para garantir
swapon -p 50 /swapfile || true

# 4. Ajusta Swappiness para 10 (Evita uso prematuro do swap em disco)
echo "vm.swappiness=10" > /etc/sysctl.d/sysctl.conf
sysctl -p /etc/sysctl.d/sysctl.conf
