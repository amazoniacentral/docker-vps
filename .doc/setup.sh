#!/bin/bash

# Cores para o terminal
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

# Diretório base do projeto ajustado
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
BASE_DIR=$(readlink -f "$SCRIPT_DIR/..")

# Garante entrada de dados via terminal
exec 3<>/dev/tty

clear
echo -e "${CYAN}================================================================${RESET}"
echo -e "${YELLOW}           GERAR DOCUMENTAÇÃO DO PROJETO${RESET}"
echo -e "${CYAN}================================================================${RESET}"

# Executa os scripts de composição na ordem correta
if [ -f "$SCRIPT_DIR/cabecalho.sh" ]; then
    bash "$SCRIPT_DIR/cabecalho.sh"
else
    echo -e "${RED}Aviso: cabecalho.sh não encontrado.${RESET}"
fi

if [ -f "$SCRIPT_DIR/estrutura.sh" ]; then
    bash "$SCRIPT_DIR/estrutura.sh"
else
    echo -e "${RED}Aviso: estrutura.sh não encontrado.${RESET}"
fi

if [ -f "$SCRIPT_DIR/variaveis.sh" ]; then
    bash "$SCRIPT_DIR/variaveis.sh"
else
    echo -e "${RED}Aviso: variaveis.sh não encontrado.${RESET}"
fi

if [ -f "$SCRIPT_DIR/blocos.sh" ]; then
    bash "$SCRIPT_DIR/blocos.sh"
else
    echo -e "${RED}Aviso: blocos.sh não encontrado.${RESET}"
fi

if [ -f "$SCRIPT_DIR/rodape.sh" ]; then
    bash "$SCRIPT_DIR/rodape.sh"
else
    echo -e "${RED}Aviso: rodape.sh não encontrado.${RESET}"
fi

echo -e "\n${GREEN}Documentação gerada com sucesso!${RESET}"
