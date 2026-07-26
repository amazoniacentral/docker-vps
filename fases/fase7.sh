# --- FASE 7: CONFIGURAÇÃO GIT E GITHUB CLI ---
echo -e "\n${YELLOW}Deseja configurar o Git e o GitHub CLI agora? (s/n)${RESET}"
read -p "> " CONFIRM_GIT < /dev/tty

if [[ "$CONFIRM_GIT" =~ ^[Ss]$ ]]; then
    # Configuração do Git
    echo -n "Digite o Nome de Usuário Git: "
    read -r GIT_USER < /dev/tty
    echo -n "Digite o E-mail do Git: "
    read -r GIT_EMAIL < /dev/tty
    
    git config --global user.name "$GIT_USER"
    git config --global user.email "$GIT_EMAIL"
    git config --global --add safe.directory '*'
    echo -e "${GREEN}Git configurado para $GIT_USER ($GIT_EMAIL).${RESET}"

    # Instalação do GitHub CLI (gh)
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}Instalando GitHub CLI (gh)...${RESET}"
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg &> /dev/null
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        apt update && apt install gh -y
    fi

    # Autenticação no GitHub
    echo -e "${YELLOW}Iniciando autenticação no GitHub...${RESET}"
    gh auth login
fi
