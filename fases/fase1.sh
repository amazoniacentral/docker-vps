# --- FASE 1: DEPENDÊNCIAS DE SISTEMA ---
echo "=============================================================================="
echo " O QUE ESTE SCRIPT FAZ:"
echo " 1. Controle de Estado (Proteção de Produção):"
echo "    Verifica se o arquivo marcador '/etc/fsilva_system_initialized' existe."
echo "    - Se NÃO existir (primeira execução): Executa 'apt-get upgrade' e"
echo "      'dist-upgrade' para atualizar todo o sistema do zero e cria a marca."
echo "    - Se JÁ existir (execuções futuras): Pula o upgrade geral do sistema"
echo "      para evitar quebras em serviços e aplicações rodando em produção."
echo ""
echo " 2. Instalação de Utilitários Essenciais:"
echo "    Instala ferramentas fundamentais de sistema, manipulação de texto e rede:"
echo "    - psmisc: Gerenciamento de processos por nome (killall, fuser)."
echo "    - util-linux: Comandos básicos do sistema (dmesg, lsblk, fallocate)."
echo "    - procps: Monitoramento de processos e recursos (ps, free, top)."
echo "    - sed & grep: Pesquisa, filtragem e edição automatizada de textos/configs."
echo "    - coreutils: Utilitários fundamentais (cp, mv, chmod, chown, cat, etc.)."
echo "    - curl: Transferência de dados e requisições HTTP para APIs."
echo "    - jq: Manipulação e filtragem de JSON diretamente via terminal."
echo "    - bc: Calculadora de precisão para uso em scripts e automações."
echo "    - net-tools: Ferramentas clássicas de rede (netstat, ifconfig)."
echo "=============================================================================="

echo "== Verificando estado de inicialização do sistema =="

MARKER_FILE="/etc/fsilva_system_initialized"

if [ ! -f "$MARKER_FILE" ]; then
    echo "🚀 Primeira execução detectada: Realizando atualização geral do sistema (upgrade)..."
    apt-get update
    apt-get upgrade -y
    apt-get dist-upgrade -y
    
    # Cria o arquivo marcador para indicar que a VM já foi inicializada/atualizada pela primeira vez
    touch "$MARKER_FILE"
    echo "✅ Sistema atualizado e marcado como inicializado em $(date)."
else
    echo "🔒 Sistema já inicializado anteriormente. Pulando upgrade geral para proteger a produção."
    apt-get update
fi

echo "== Garantindo utilitários essenciais =="
apt-get install -y psmisc util-linux procps sed grep coreutils curl jq bc net-tools
