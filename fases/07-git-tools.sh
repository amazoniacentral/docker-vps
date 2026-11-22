# --- FASE 7: GIT, CHAVE SSH, GITHUB CLI E LOGIN DOCKER (OBRIGATÓRIO E RESILIENTE) ---
echo "=============================================================================="
echo " O QUE ESTE SCRIPT FAZ:"
echo " 1. Instalação e Verificação Obrigatória de Git e GitHub CLI (gh):"
echo "    - Instala e garante a presença de ambos no sistema."
echo " 2. Chave SSH Obrigatória:"
echo "    - Garante que existe uma chave SSH configurada e vinculada ao GitHub."
echo " 3. Configuração Ativa do Git:"
echo "    - Exige usuário e e-mail válidos configurados globalmente."
echo " 4. Autenticação Concluída no GitHub e Docker:"
echo "    - Só permite avançar na automação após o token garantir sucesso no gh e ghcr.io."
echo "    - LOOP DE INSISTÊNCIA: Insiste infinitamente até que a credencial seja válida."
echo "=============================================================================="

echo "== 1. Verificando e instalando Git e GitHub CLI (gh) =="
if ! command -v git &> /dev/null; then
    echo "Instalando Git..."
    apt-get update && apt-get install -y git
fi

if ! command -v gh &> /dev/null; then
    echo "Instalando GitHub CLI (gh)..."
    install -m 0755 -d /usr/share/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg &> /dev/null
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt-get update && apt-get install -y gh
fi

# Loop de insistência obrigatória: Só sai daqui quando TUDO estiver configurado e conectado com sucesso
while true; do
    echo "--------------------------------------------------------"
    echo "🔄 Validando estado das configurações de Git, SSH e Tokens..."
    
    TUDO_CONFIGURADO=true
    
    # Valida Git User/Email
    CURRENT_GIT_USER=$(git config --global user.name || true)
    CURRENT_GIT_EMAIL=$(git config --global user.email || true)
    if [ -z "$CURRENT_GIT_USER" ] || [ -z "$CURRENT_GIT_EMAIL" ]; then
        TUDO_CONFIGURADO=false
        echo "⚠️ Git sem usuário ou e-mail configurados."
        echo -n "Digite o seu Nome de Usuário de exibição Git (ex: Francisco Silva): "
        read -r GIT_USER < /dev/tty
        echo -n "Digite o seu E-mail do Git (ex: radioamazoniacentral@gmail.com): "
        read -r GIT_EMAIL < /dev/tty
        if [ -n "$GIT_USER" ] && [ -n "$GIT_EMAIL" ]; then
            git config --global user.name "$GIT_USER"
            git config --global user.email "$GIT_EMAIL"
            git config --global --add safe.directory '*'
            echo "✅ Git configurado com sucesso!"
        fi
    fi

    # Valida Chave SSH
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    if [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_rsa" ]; then
        TUDO_CONFIGURADO=false
        echo "⚠️ Nenhuma chave SSH encontrada no sistema."
        echo "🔑 Gerando chave ed25519 nova..."
        ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" &> /dev/null
        chmod 600 "$HOME/.ssh/id_ed25519"
        echo "=============================================================================="
        echo "📋 ATENÇÃO: COPIE A CHAVE PÚBLICA ABAIXO E ADICIONE NO SEU GITHUB (Settings -> SSH keys):"
        cat "$HOME/.ssh/id_ed25519.pub"
        echo "=============================================================================="
        read -p "Pressione [Enter] após adicionar a chave no GitHub para prosseguir..." < /dev/tty
    fi

    if ! grep -q "github.com" ~/.ssh/known_hosts 2>/dev/null; then
        ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
    fi

    # Valida Login GitHub CLI (gh) e Docker (ghcr.io)
    GH_LOGADO=false
    DOCKER_LOGADO=false

    if gh auth status &> /dev/null; then
        GH_LOGADO=true
    fi

    if grep -q "ghcr.io" ~/.docker/config.json 2>/dev/null; then
        DOCKER_LOGADO=true
    fi

    if [ "$GH_LOGADO" = false ] || [ "$DOCKER_LOGADO" = false ]; then
        TUDO_CONFIGURADO=false
        echo "⚠️ Autenticação pendente no GitHub CLI e/ou Docker (ghcr.io)."
        echo "💡 Dica: O Token (PAT) do GitHub precisa ter obrigatoriamente os escopos: repo, read:packages, read:org."
        echo -n "Digite seu Token do GitHub (PAT válido): "
        read -rs GH_TOKEN_INPUT < /dev/tty
        echo ""

        if [ -n "$GH_TOKEN_INPUT" ]; then
            if [ "$GH_LOGADO" = false ]; then
                if echo "$GH_TOKEN_INPUT" | gh auth login --with-token; then
                    gh auth setup-git
                    GH_LOGADO=true
                else
                    echo "❌ Falha na autenticação do GitHub CLI com este token. Verifique os escopos (repo, read:packages, read:org) e tente novamente."
                fi
            fi

            if [ "$DOCKER_LOGADO" = false ] && command -v docker &> /dev/null && [ "$GH_LOGADO" = true ]; then
                echo -n "Digite seu usuário do GitHub (ex: amazoniacentral): "
                read -r GH_USERNAME < /dev/tty
                if [ -n "$GH_USERNAME" ]; then
                    if echo "$GH_TOKEN_INPUT" | docker login ghcr.io -u "$GH_USERNAME" --password-stdin; then
                        DOCKER_LOGADO=true
                    else
                        echo "❌ Falha no login do Docker (ghcr.io). Tente novamente."
                    fi
                fi
            fi
        else
            echo "❌ Token vazio não é permitido. Tentando novamente..."
        fi
    fi

    # Se tudo estiver perfeitamente configurado e conectado, sai do loop e avança
    if [ "$TUDO_CONFIGURADO" = true ] && gh auth status &> /dev/null && { [ ! -f /var/run/docker.sock ] || grep -q "ghcr.io" ~/.docker/config.json 2>/dev/null; }; then
        echo "✅ Todas as verificações da Fase 7 foram concluídas, configuradas e conectadas com sucesso!"
        break
    else
        echo "⚠️ Configuração incompleta ou falha de autenticação detectada."
        echo "🔄 Reiniciando o processo de validação automaticamente em instantes..."
        sleep 2
    fi
done
