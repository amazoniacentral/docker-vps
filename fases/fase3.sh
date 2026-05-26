# --- FASE 3: INSTALAÇÃO SILENCIOSA E BASE ---
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
