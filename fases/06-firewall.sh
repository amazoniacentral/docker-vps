# --- FASE 6: CONFIGURAÇÃO INTELIGENTE DO FIREWALL (IPTABLES + CLOUDFLARE) ---
echo "=============================================================================="
echo " O QUE ESTE SCRIPT FAZ:"
echo " 1. Instalação do iptables-persistent:"
echo "    - Garante que as regras salvas sobrevivam a reboots da VPS."
echo " 2. Detecção Dinâmica da Porta SSH:"
echo "    - Identifica automaticamente qual porta o serviço SSH está usando no momento"
echo "      (padrão 22 ou personalizada), evitando que você seja banido da sua VPS."
echo " 3. Estratégia de Rede Baseada em Docker (com Menu Cloudflare):"
echo "    - Permite escolher entre o Modo RESTRITO (apenas IPs da Cloudflare"
echo "      nas portas 80/443) ou ABERTO para gerenciar o tráfego dos containers."
echo " 4. Persistência de Regras:"
echo "    - Salva permanentemente as regras via 'netfilter-persistent save'."
echo "=============================================================================="

# 1. Instalação silenciosa do iptables-persistent para persistência
if ! dpkg -l | grep -q iptables-persistent; then
    echo "Instalando iptables-persistent para salvar regras entre reboots..."
    export DEBIAN_FRONTEND=noninteractive
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
    apt-get update && apt-get install -y iptables-persistent &>/dev/null
fi

# 2. Desativa UFW se estiver ativo para evitar conflitos
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "active"; then
        echo "UFW ativo detectado. Desativando para assumir controle total via IPTABLES..."
        ufw --force disable > /dev/null
    fi
fi

# 3. Detectar a porta real do SSH para não trancar o usuário para fora do Host
SSH_PORT=$(ss -tulpn | grep sshd | grep -oP '(?<=:)\d+(?=\s)' | head -n1)
SSH_PORT=${SSH_PORT:-22}

echo "== Configurando segurança nas correntes DOCKER-USER e INPUT =="

# Garante que a porta SSH dinâmica está aberta no Host (Input)
iptables -C INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT

# Menu interativo do modo de segurança para o Docker (Portas 80/443)
while true; do
    echo "----------------------------------------------------"
    echo "SELECIONE O MODO DE SEGURANÇA DOCKER (Portas 80/443):"
    echo "1) RESTRITO (Apenas Cloudflare)"
    echo "2) ABERTO (Qualquer IP)"
    echo "----------------------------------------------------"
    
    read -p "Sua opção [1 ou 2]: " modo < /dev/tty

    case $modo in
        1|2) break ;;
        *) echo "RESPOSTA INVÁLIDA. Digite 1 ou 2."; sleep 1 ;;
    esac
done

# Limpa e configura DOCKER-USER
iptables -N DOCKER-USER 2>/dev/null || iptables -F DOCKER-USER
iptables -A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A DOCKER-USER -i docker0 -j ACCEPT
iptables -A DOCKER-USER -i br-+ -j ACCEPT

if [[ "$modo" == "1" ]]; then
    echo "Aplicando Modo RESTRITO (Cloudflare nas portas 80/443)..."
    CLOUDFLARE_IPS=(
        173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 
        141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 
        197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 
        104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
    )
    for ip in "${CLOUDFLARE_IPS[@]}"; do
        iptables -A DOCKER-USER -s "$ip" -p tcp -m multiport --dports 80,443 -j ACCEPT
    done
    iptables -A DOCKER-USER -i eth0 -p tcp -m multiport --dports 80,443 -j DROP
else
    echo "Aplicando Modo ABERTO (Portas 80/443 liberadas para todos)..."
    iptables -A DOCKER-USER -p tcp -m multiport --dports 80,443 -j ACCEPT
fi

iptables -A DOCKER-USER -j RETURN
echo -e "${GREEN}✅ Firewall focado em Containers (DOCKER-USER) aplicado com sucesso!${RESET}"

# Salva as alterações de forma persistente
netfilter-persistent save &>/dev/null || true
echo -e "${GREEN}✅ Regras de firewall salvas permanentemente com sucesso!${RESET}\n"
