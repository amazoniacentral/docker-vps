# --- FASE 3: INSTALAÇÃO SILENCIOSA E BASE ---
echo "=============================================================================="
echo " O QUE ESTE SCRIPT FAZ:"
echo " 1. Configuração Não-Interativa (Modo Silencioso):"
echo "    - Preconfigura o 'iptables-persistent' para salvar regras automaticamente"
echo "      sem abrir telas azuis ou paradas interativas (debconf-set-selections)."
echo "    - Força o ambiente global para não exibir prompts (DEBIAN_FRONTEND)."
echo " 2. Atualização e Sincronização de Repositórios:"
echo "    - Atualiza a lista de pacotes com segurança (apt-get update), pulando o"
echo "      upgrade geral automático para proteger a produção de quebras."
echo " 3. Instalação de Pacotes Base Essenciais:"
echo "    - netfilter-persistent / iptables-persistent: Regras de firewall."
echo "    - ca-certificates, gnupg, lsb-release: Segurança e chaves de repositório."
echo "    - htop, unzip, tree, git: Utilitários de sistema, arquivos e repositórios."
echo "    - zram-tools: Otimização e compactação de memória RAM."
echo "    - htpdate: Sincronização precisa de relógio via HTTP (Google)."
echo "    - fail2ban: Proteção contra ataques de força bruta no SSH."
echo " 4. Ajuste Temporal:"
echo "    - Define o fuso horário oficial para America/Sao_Paulo."
echo "=============================================================================="

echo "== Configurando ambiente não-interativo =="
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections

export DEBIAN_FRONTEND=noninteractive

echo "== Atualizando Repositórios (Seguro para Produção) =="
apt-get update

echo "== Instalando pacotes base =="
apt-get install -y netfilter-persistent iptables-persistent \
  ca-certificates gnupg lsb-release htop unzip zram-tools htpdate fail2ban tree git

# Ajustar Relógio
timedatectl set-timezone America/Sao_Paulo
htpdate -s -t google.com
