# --- FASE 1: DEPENDÊNCIAS DE SISTEMA ---
echo "== Instalando utilitários essenciais =="
apt-get update
apt-get install -y psmisc util-linux procps sed grep coreutils curl jq bc net-tools
