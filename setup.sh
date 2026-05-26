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

echo "== Carregando Fase 1: Dependências do Sistema =="
source <(curl -fsSL "${BASE_URL}/fase1.sh")

echo "== Carregando Fase 2: Desbloqueio e Limpeza =="
source <(curl -fsSL "${BASE_URL}/fase2.sh")

echo "== Carregando Fase 3: Instalação Silenciosa e Base =="
source <(curl -fsSL "${BASE_URL}/fase3.sh")

echo "== Carregando Fase 4: Performance (ZRAM & SWAP) =="
source <(curl -fsSL "${BASE_URL}/fase4.sh")

# Controle de Fluxo do Docker e Firewall
echo "== Carregando Fase 5: Instalação / Verificação do Docker =="
source <(curl -fsSL "${BASE_URL}/fase5.sh")

# Gerenciamento Dinâmico do Firewall (Com ou Sem Docker)
echo "== Carregando Fase 6: Configuração Inteligente do Firewall =="
source <(curl -fsSL "${BASE_URL}/fase6.sh")

echo "== Carregando Fase 7: Configuração Git =="
source <(curl -fsSL "${BASE_URL}/fase7.sh")

echo "== Carregando Fase 8: SSH e Segurança =="
source <(curl -fsSL "${BASE_URL}/fase8.sh")

echo "== Executando Limpeza Final =="
apt autoremove -y && apt autoclean

echo "== Carregando Fase 9: Log de Monitoramento Final =="
source <(curl -fsSL "${BASE_URL}/fase9.sh")
