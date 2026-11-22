# --- FASE 5: DOCKER ENGINE OFICIAL ---
echo "=============================================================================="
echo " O QUE ESTE SCRIPT FAZ:"
echo " 1. Verificação de Instalação Existente:"
echo "    - Checa se o Docker já está instalado na VPS. Se já estiver, pula o"
echo "      processo para economizar tempo e evitar sobrescrever configurações."
echo " 2. Configuração do Repositório Oficial do Docker:"
echo "    - Cria o diretório seguro de chaves criptográficas (keyrings)."
echo "    - Baixa e instala a chave GPG oficial da Docker Inc."
echo "    - Adiciona o repositório oficial do Docker adaptado para a versão exata"
echo "      do seu Debian (Bookworm) e arquitetura do processador."
echo " 3. Instalação Completa do Ecossistema Docker:"
echo "    - Instala o Docker Engine (daemon), CLI, containerd, plugin Buildx"
echo "      e o indispensável Docker Compose (docker-compose-plugin)."
echo " 4. Inicialização Automática:"
echo "    - Habilita e inicia o serviço do Docker imediatamente (systemctl)."
echo "=============================================================================="

echo "== Verificando instalação do Docker Engine =="

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
