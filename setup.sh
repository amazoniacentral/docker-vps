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

# 2. Verificar se o sistema é Debian 12
OS_ID=""
OS_VERSION=""
OS_PRETTY="Desconhecido"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_VERSION="$VERSION_ID"
    OS_PRETTY="$PRETTY_NAME"
fi

if [ "$OS_ID" != "debian" ] || [ "$OS_VERSION" != "12" ]; then
    echo -e "${RED}================================================================${RESET}"
    echo -e "${YELLOW}⚠️  AVISO DE COMPATIBILIDADE${RESET}"
    echo -e "${RED}================================================================${RESET}"
    echo -e "Sistema detectado: ${CYAN}${OS_PRETTY}${RESET}"
    echo -e "Este script foi desenvolvido e testado com foco exclusivo no ${GREEN}Debian 12 (Bookworm)${RESET}."
    echo -e "Executar em outras distribuições ou versões pode causar falhas ou incompatibilidades."
    echo ""
    read -p "Deseja continuar mesmo assim? (s/N): " CONTINUAR < /dev/tty
    if [[ ! "$CONTINUAR" =~ ^[Ss]$ ]]; then
        echo -e "${RED}Execução cancelada pelo usuário.${RESET}"
        exit 1
    fi
fi

clear
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           INICIANDO SETUP INTEGRADO (9 FASES)${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# Identifica o diretório do script (com fallback caso rode via curl | bash)
SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$PWD")")

if [ -d "${SCRIPT_DIR}/fases" ]; then
    MODO_LOCAL=true
    BASE_PATH="${SCRIPT_DIR}/fases"
    echo -e "${GREEN}📁 Pasta local 'fases' encontrada. Carregando arquivos locais...${RESET}"
else
    MODO_LOCAL=false
    BASE_PATH="https://raw.githubusercontent.com/amazoniacentral/docker-vps/main/fases"
    echo -e "${CYAN}🌐 Pasta local 'fases' não encontrada. Carregando via GitHub...${RESET}"
fi

# Função para carregar a fase localmente ou remotamente
carregar_fase() {
    local arquivo="$1"
    if [ "$MODO_LOCAL" = true ]; then
        source "${BASE_PATH}/${arquivo}"
    else
        source <(curl -fsSL "${BASE_PATH}/${arquivo}")
    fi
}

# --- EXECUÇÃO DAS 9 FASES ---

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 1: Otimização ZRAM ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
carregar_fase "01-zram.sh"

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 2: Swapfile de Segurança ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
carregar_fase "02-swapfile.sh"

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 3: Pacotes Base e Fail2Ban ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
carregar_fase "03-base-fail2ban.sh"

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 4: Docker Engine Oficial ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
carregar_fase "04-docker-install.sh"

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 5: Limpeza de Resíduos Docker ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
carregar_fase "05-docker-cleanup.sh"

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 6: Firewall Inteligente IPTABLES ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
carregar_fase "06-firewall.sh"

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 7: Git e GitHub CLI ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
carregar_fase "07-git-tools.sh"

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 8: Hardening do SSH ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
carregar_fase "08-ssh-hardening.sh"

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Executando Limpeza do Sistema (Autoremove/Autoclean) ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
apt autoremove -y && apt autoclean

echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}== Carregando Fase 9: Log de Monitoramento Final (Raio-X) ==${RESET}"
echo -e "${CYAN}================================================================${RESET}"
carregar_fase "09-raiox.sh"
