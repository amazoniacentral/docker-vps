#!/bin/bash

# =================================================================
# SCRIPT DE FIREWALL - MODO INTERATIVO FORÇADO (TTY)
# =================================================================

# 1. Verificar se é root
if [[ $EUID -ne 0 ]]; then
   echo "Erro: Este script deve ser executado como root."
   exit 1
fi

# 2. Loop de pergunta persistente (Só sai se responder 1 ou 2)
while true; do
    echo "----------------------------------------------------"
    echo "SELECIONE O MODO DE SEGURANÇA (Portas 80/443):"
    echo "1) RESTRITO (Apenas Cloudflare)"
    echo "2) ABERTO (Qualquer IP)"
    echo "----------------------------------------------------"
    
    # Força a leitura a partir do terminal para evitar pulos
    read -p "Sua opção [1 ou 2]: " modo < /dev/tty

    case $modo in
        1)
            echo "Modo Restrito selecionado."
            break
            ;;
        2)
            echo "Modo Aberto selecionado."
            break
            ;;
        *)
            echo "RESPOSTA INVÁLIDA. Você deve digitar 1 ou 2."
            sleep 1
            ;;
    esac
done

# 3. Execução das configurações
echo "Limpando regras anteriores e configurando..."

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH Access'

if [[ "$modo" == "1" ]]; then
    CLOUDFLARE_IPS=(
        173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 
        141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 
        197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 
        104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
    )

    for ip in "${CLOUDFLARE_IPS[@]}"; do
        ufw allow from "$ip" to any port 80,443 proto tcp > /dev/null
    done
    echo "Filtro Cloudflare aplicado."
else
    ufw allow 80/tcp
    ufw allow 443/tcp
    echo "Portas web abertas para o mundo."
fi

# 4. Ativação Final
ufw --force enable
ufw reload

echo "----------------------------------------------------"
echo "CONFIGURAÇÃO FINALIZADA COM SUCESSO."
ufw status verbose
echo "----------------------------------------------------"
