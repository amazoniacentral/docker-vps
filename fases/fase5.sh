# --- FASE 5: DOCKER ENGINE OFICIAL ---
echo -e "\n${YELLOW}Verificando instalação do Docker Engine...${RESET}"

if command -v docker &> /dev/null; then
    echo "✅ Docker já está instalado ($(docker --version)). Pulando instalação..."
else
    echo "== Instalando Docker Engine Oficial =="
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    echo "✅ Docker instalado com sucesso!"
fi
