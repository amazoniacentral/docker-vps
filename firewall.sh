#!/bin/bash

# =================================================================
# SCRIPT DE FIREWALL DEFINITIVO - IPTABLES + PERSISTÊNCIA (V2)
# =================================================================

# 1. Verificar se é root
if [[ $EUID -ne 0 ]]; then
   echo "Erro: Este script deve ser executado como root."
   exit 1
fi

# 2. Instalação do iptables-persistent (caso não exista)
if ! dpkg -l | grep -q iptables-persistent; then
    echo "Instalando iptables-persistent para salvar regras entre reboots..."
    # Configura o instalador para não fazer perguntas interativas nas telas azuis
    export DEBIAN_FRONTEND=noninteractive
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
    apt-get update && apt-get install -y iptables-persistent
fi

# 3. Desativar UFW (Apenas se ele estiver instalado)
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "active"; then
        echo "UFW detectado e ativo. Desativando para assumir controle total via IPTABLES..."
        ufw --force disable > /dev/null
    else
        echo "UFW detectado, mas já está desativado."
    fi
fi

# 4. Loop de seleção de modo
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

echo "Configurando DOCKER-USER..."

# 5. Limpeza e Configuração de Base
# Limpa a corrente que o Docker reserva para administradores
iptables -F DOCKER-USER

# Permite tráfego estabelecido (essencial para não derrubar conexões SSH ativas)
iptables -A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Garante acesso SSH na porta 22 (Tabela INPUT do Sistema)
# Isso evita que você perca o acesso à VPS
iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 6. Aplicação das Regras
if [[ "$modo" == "1" ]]; then
    echo "Aplicando Modo RESTRITO..."
    
    CLOUDFLARE_IPS=(
        173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 
        141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 
        197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 
        104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
    )

    for ip in "${CLOUDFLARE_IPS[@]}"; do
        iptables -A DOCKER-USER -s "$ip" -p tcp -m multiport --dports 80,443 -j ACCEPT
    done

    # BLOQUEIO: Qualquer outro IP que tentar 80/443 no Docker pela interface de internet (eth0)
    iptables -A DOCKER-USER -i eth0 -p tcp -m multiport --dports 80,443 -j DROP
    echo "Filtro Cloudflare aplicado com sucesso."
else
    echo "Aplicando Modo ABERTO..."
    iptables -A DOCKER-USER -p tcp -m multiport --dports 80,443 -j ACCEPT
    echo "Acesso liberado para todo o mundo."
fi

# Retorno padrão para outras regras do Docker (essencial para o funcionamento do Docker)
iptables -A DOCKER-USER -j RETURN

# 7. SALVAMENTO PERSISTENTE
echo "Salvando regras permanentemente em /etc/iptables/rules.v4..."
netfilter-persistent save

echo "----------------------------------------------------"
echo "FIREWALL CONFIGURADO E SALVO."
echo "As regras sobreviverão ao REBOOT da VPS."
echo "----------------------------------------------------"
iptables -L DOCKER-USER -n --line-numbers
