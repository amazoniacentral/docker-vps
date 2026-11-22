# --- FASE 3: INSTALAÇÃO SILENCIOSA, BASE E FAIL2BAN INTERATIVO ---
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
echo " 4. Ajuste Temporal e Hardening Fail2Ban:"
echo "    - Define o fuso horário oficial para America/Sao_Paulo."
echo "    - Configura whitelist interativa, banimento de 24h e maxretry 3."
echo "=============================================================================="

echo "== Configurando ambiente não-interativo =="
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections

export DEBIAN_FRONTEND=noninteractive

echo "== Atualizando Repositórios (Seguro para Produção) =="
apt-get update

echo "== Instalando pacotes base e Fail2Ban =="
apt-get install -y netfilter-persistent iptables-persistent \
  ca-certificates gnupg lsb-release htop unzip zram-tools htpdate fail2ban tree git

# Ajustar Relógio
timedatectl set-timezone America/Sao_Paulo
htpdate -s -t google.com &>/dev/null || true

echo -e "\n== Configurando Whitelist e Regras de Bloqueio do Fail2Ban =="
echo "Digite os IPs que deseja ignorar (Whitelist), separados por ESPAÇO."
echo "Exemplo: 192.168.1.10 200.50.100.20 (ou pressione ENTER para pular):"
printf "IPs: "
read -r USER_IPS < /dev/tty

# Define os IPs padrões (localhost) e anexa os informados pelo usuário
IGNORE_LIST="127.0.0.1/8 ::1 ${USER_IPS}"

# Cria configuração local robusta para o sshd
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = ${IGNORE_LIST}
bantime  = 1d
findtime  = 10m
maxretry = 3

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

systemctl enable fail2ban &>/dev/null
systemctl restart fail2ban

# Pausa de segurança para garantir que o socket do fail2ban suba corretamente
sleep 2

echo -e "${GREEN}✅ Fail2Ban configurado e ativo com sucesso!${RESET}"
echo -e "${CYAN}----------------------------------------------------------------${RESET}"
echo -e "IPs na Whitelist: ${YELLOW}${IGNORE_LIST}${RESET}"
echo -e "Status do SSH Jail:"
fail2ban-client status sshd
echo -e "${CYAN}----------------------------------------------------------------${RESET}"
