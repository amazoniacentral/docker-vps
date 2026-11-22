# --- FASE 6: CONFIGURAÇÃO INTELIGENTE DO FIREWALL ---
echo "=============================================================================="
echo " O QUE ESTE SCRIPT FAZ:"
echo " 1. Detecção Dinâmica da Porta SSH:"
echo "    - Identifica automaticamente qual porta o serviço SSH está usando no momento"
echo "      (padrão 22 ou personalizada), evitando que você seja banido da sua VPS."
echo " 2. Estratégia Inteligente Baseada em Docker:"
echo "    - Se o Docker estiver presente, aplica as regras de segurança direto na"
echo "      corrente 'DOCKER-USER' para proteger os containers sem quebrar o tráfego."
echo "    - Libera tráfego interno do Docker, conexões estabelecidas, e as portas"
echo "      web padrão (80 e 443), bloqueando o restante."
echo " 3. Persistência de Regras:"
echo "    - Salva permanentemente as regras via 'netfilter-persistent save' para"
echo "      que elas continuem ativas mesmo após reiniciar o servidor."
echo "=============================================================================="

# Detectar a porta real do SSH para não trancar o usuário para fora do Host
SSH_PORT=$(ss -tulpn | grep sshd | grep -oP '(?<=:)\d+(?=\s)' | head -n1)
SSH_PORT=${SSH_PORT:-22}

if command -v docker >/dev/null 2>&1; then
    echo "== [CENÁRIO DOCKER] Aplicando regras na corrente DOCKER-USER =="
    
    iptables -N DOCKER-USER 2>/dev/null || iptables -F DOCKER-USER
    iptables -A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A DOCKER-USER -i docker0 -j ACCEPT
    iptables -A DOCKER-USER -i br-+ -j ACCEPT
    iptables -A DOCKER-USER -p tcp --dport 80 -j ACCEPT
    iptables -A DOCKER-USER -p tcp --dport 443 -j ACCEPT
    iptables -A DOCKER-USER -j DROP
    
    echo "Firewall focado em Containers (DOCKER-USER) aplicado com sucesso!"
else
    echo "== [CENÁRIO HOST PURO] Aplicando regras de isolamento na corrente INPUT =="
    
    # Define a política padrão de INPUT como DROP (Bloqueia tudo por padrão externo)
    iptables -P INPUT ACCEPT # Garante temporariamente para não derrubar a sessão ativa
    iptables -F INPUT
    
    # 1. Permitir tráfego interno da própria máquina (Loopback)
    iptables -A INPUT -i lo -j ACCEPT
    
    # 2. Manter conexões ativas e já estabelecidas abertas
    iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    
    # 3. Liberar Porta SSH Dinâmica detectada
    iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT
    
    # 4. Liberar Portas Web padrão do Host (Caso suba Nginx/Apache direto na máquina)
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    # 5. Aplicar o bloqueio definitivo para o resto
    iptables -P INPUT DROP
    
    echo "Firewall focado no Host (INPUT) aplicado com sucesso na porta SSH ${SSH_PORT}!"
fi

# Salva as alterações de forma persistente
netfilter-persistent save
