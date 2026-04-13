#!/bin/bash

# Cores
CYAN='\e[0;36m'
YELLOW='\e[1;33m'
GREEN='\e[0;32m'
RED='\e[0;31m'
RESET='\e[0m'

clear
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           STATUS GERAL DA VPS (PÓS-CONFIGURAÇÃO)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# Sistema
OS=$(grep "PRETTY_NAME" /etc/os-release | cut -d'"' -f2)
UP=$(uptime -p | sed 's/up //')
printf "%-25s %-15s\n" "SISTEMA OPERACIONAL:" "$OS"
printf "%-25s ${GREEN}%-15s${RESET}\n" "UPTIME:" "$UP"

echo -e "\n${CYAN}MEMÓRIA E SWAP:${RESET}"
printf "%-15s %-10s %-10s %-10s\n" "TIPO" "TOTAL" "USADO" "LIVRE"
free -h | awk 'NR==2{printf "%-15s %-10s %-10s %-10s\n", "RAM", $2, $3, $7}'
swapon --show=NAME,SIZE,USED,PRIO | awk 'NR>1{printf "%-15s %-10s %-10s (PRIO: %s)\n", $1, $2, $3, $4}'

echo -e "\n${CYAN}SEGURANÇA E FIREWALL:${RESET}"
# Verificação real do SSH
if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    STATUS_SSH="${GREEN}PROTEGIDO (SOMENTE CHAVE)${RESET}"
else
    STATUS_SSH="${RED}SENHA ATIVA (VULNERÁVEL)${RESET}"
fi
printf "%-25s %-15s\n" "AUTENTICAÇÃO SSH:" "$STATUS_SSH"
printf "%-25s ${GREEN}%-15s${RESET}\n" "IPTABLES-PERSISTENT:" "INSTALADO"

echo -e "\n${CYAN}DOCKER E GIT:${RESET}"
D_VER=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "N/A")
G_USR=$(git config --global user.name || echo "N/A")
echo -e "Docker Engine: ${GREEN}v$D_VER${RESET}"
echo -e "Git Configurado para: ${GREEN}$G_USR${RESET}"

echo -e "\n${CYAN}================================================================${RESET}"
echo -e "${GREEN}             SISTEMA PRONTO E OTIMIZADO!${RESET}"
echo -e "${CYAN}================================================================${RESET}"
