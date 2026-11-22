#!/bin/bash
set -e

# Cores para formatação
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
RESET="\e[0m"

# Garante que roda como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Este script precisa ser executado como root (sudo).${RESET}"
    exit 1
fi

echo "=============================================================================="
echo " O QUE ESTE SCRIPT FAZ:"
echo " 1. Instalação e Ativação do Fail2Ban:"
echo "    - Atualiza os pacotes e instala o Fail2Ban para proteção contra força bruta."
echo " 2. Whitelist Inteligente:"
echo "    - Permite definir IPs confiáveis para que nunca sejam banidos por engano."
echo " 3. Hardening de Segurança SSH:"
echo "    - Configura banimento de 24h após 3 tentativas falhas em uma janela de 10min."
echo "=============================================================================="

echo "== [1/3] Instalando Fail2Ban =="
apt-get update -y &>/dev/null || true
apt-get install -y fail2ban &>/dev/null || true

echo -e "\n== [2/3] Configurando Whitelist e Regras de Bloqueio =="
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

echo -e "\n== [3/3] Reiniciando e Ativando o Serviço =="
systemctl enable fail2ban &>/dev/null
systemctl restart fail2ban

echo -e "${GREEN}✅ Fail2Ban configurado e ativo com sucesso!${RESET}"
echo -e "${CYAN}----------------------------------------------------------------${RESET}"
echo -e "IPs na Whitelist: ${YELLOW}${IGNORE_LIST}${RESET}"
echo -e "Status do SSH Jail:"
fail2ban-client status sshd
echo -e "${CYAN}----------------------------------------------------------------${RESET}"
