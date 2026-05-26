# --- FASE 7: CONFIGURAÇÃO GIT ---
echo -e "\n${YELLOW}Deseja configurar o Git agora? (s/n)${RESET}"
read -p "> " CONFIRM_GIT < /dev/tty
if [[ "$CONFIRM_GIT" =~ ^[Ss]$ ]]; then
    echo -n "Digite o Nome de Usuário Git: "
    read -r GIT_USER < /dev/tty
    echo -n "Digite o E-mail do Git: "
    read -r GIT_EMAIL < /dev/tty
    
    git config --global user.name "$GIT_USER"
    git config --global user.email "$GIT_EMAIL"
    git config --global --add safe.directory '*'
    echo -e "${GREEN}Git configurado para $GIT_USER ($GIT_EMAIL).${RESET}"
fi
