#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then 
  echo "Execute este script como root"
  exit 1
fi

echo "== Corrigindo erros de repositório anteriores =="
rm -f /etc/apt/sources.list.d/docker.list

echo "== Atualizando sistema =="
apt update && apt upgrade -y

echo "== Instalando pacotes básicos =="
apt install -y ca-certificates curl gnupg lsb-release ufw htop unzip zram-tools htpdate fail2ban

#Ajustar Relógio
timedatectl set-timezone America/Sao_Paulo
htpdate -s -t google.com

echo "== Configurando Repositório Docker (Debian) =="
install -m 0755 -d /etc/apt/keyrings
# Removendo chave antiga se existir para evitar conflito
rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
chmod a+r /etc/apt/keyrings/docker.gpg

# CORREÇÃO AQUI: lsb_release -cs (com 'b')
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update

echo "== Instalando Docker v27 (Compatível com Traefik) =="
apt install -y --allow-downgrades \
  docker-ce=5:27.3.1-1~debian.12~bookworm \
  docker-ce-cli=5:27.3.1-1~debian.12~bookworm \
  containerd.io docker-buildx-plugin docker-compose-plugin

apt-mark hold docker-ce docker-ce-cli
systemctl enable docker
systemctl start docker

echo "== Configurando Firewall =="
# 1. Reseta as regras para evitar lixo (Opcional, mas recomendado)
ufw --force reset

# 2. Define a política padrão (Bloquear tudo que entra, permitir o que sai)
ufw default deny incoming
ufw default allow outgoing

# 3. Abre as portas necessárias
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# 4. Ativa o firewall de verdade (O --force vai antes do comando de ação no reset, no enable é apenas enable)
ufw --force enable

# 5. Aplica as alterações
ufw reload

echo "== Configurando Traefik (Rede e Permissões) =="
docker network create web 2>/dev/null || true

echo "== Configurando ZRAM (Camada 1: RAM Comprimida) =="
cat <<EOF > /etc/default/zramswap
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
systemctl restart zramswap

echo "== Configurando Swap de Disco (Camada 2: 4GB de Reserva) =="
if [ ! -f /swapfile ]; then
  echo "Criando swapfile..."
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


echo "== Limpeza final =="
apt autoremove -y && apt autoclean

echo "Sistema pronto e corrigido!"
