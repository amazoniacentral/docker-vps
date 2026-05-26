# --- FASE 5: DOCKER ENGINE V27 ---
echo -e "\n${YELLOW}Deseja instalar/garantir o Docker Engine v27? (s/n)${RESET}"
read -p "> " INSTALL_DOCKER < /dev/tty
if [[ "$INSTALL_DOCKER" =~ ^[Ss]$ ]]; then
    echo "== Configurando Docker v27.3.1 =="
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y --allow-downgrades \
      docker-ce=5:27.3.1-1~debian.12~bookworm \
      docker-ce-cli=5:27.3.1-1~debian.12~bookworm \
      containerd.io docker-buildx-plugin docker-compose-plugin
    apt-mark hold docker-ce docker-ce-cli
    systemctl enable --now docker
fi
