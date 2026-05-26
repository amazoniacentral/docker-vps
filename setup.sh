#!/bin/bash
set -e

# =================================================================
# SETUP ABSOLUTO, FIREWALL E MONITORAMENTO - FSilva Cloud
# =================================================================

# 1. Verificar se é root
if [ "$EUID" -ne 0 ]; then 
  echo "Erro: Execute este script como root."
  exit 1
fi

# Definição de Cores
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

clear
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           INICIANDO SETUP INTEGRADO (SISTEMA + FIREWALL)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# URL Base onde os arquivos das fases estão hospedados
BASE_URL="https://raw.githubusercontent.com/amazoniacentral/docker-vps/main/fases"

# --- EXECUÇÃO DAS FASES REMOTAS ---

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 1: Dependências do Sistema ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
source <(curl -fsSL "${BASE_URL}/fase1.sh")

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 2: Desbloqueio e Limpeza =${RESET}"
echo -e "${CYAN}================================================================${RESET}"
source <(curl -fsSL "${BASE_URL}/fase2.sh")

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 3: Instalação Silenciosa e Base ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
source <(curl -fsSL "${BASE_URL}/fase3.sh")

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 4: Performance (ZRAM & SWAP) ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
source <(curl -fsSL "${BASE_URL}/fase4.sh")

# Controle de Fluxo do Docker e Firewall
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 5: Instalação / Verificação do Docker ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
source <(curl -fsSL "${BASE_URL}/fase5.sh")

# Gerenciamento Dinâmico do Firewall (Com ou Sem Docker)
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 6: Configuração Inteligente do Firewall ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
source <(curl -fsSL "${BASE_URL}/fase6.sh")

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 7: Configuração Git ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
source <(curl -fsSL "${BASE_URL}/fase7.sh")

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 8: SSH e Segurança ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
source <(curl -fsSL "${BASE_URL}/fase8.sh")

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Executando Limpeza Final ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
apt autoremove -y && apt autoclean

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 9: Log de Monitoramento Final ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
source <(curl -fsSL "${BASE_URL}/fase9.sh")
