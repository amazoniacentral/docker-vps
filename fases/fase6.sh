# --- FASE 6: CONFIGURAÇÃO INTELIGENTE DO FIREWALL ---

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
    
    echo -e "${GREEN}Firewall focado em Containers (DOCKER-USER) aplicado com sucesso!${RESET}"
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
    
    echo -e "${GREEN}Firewall focado no Host (INPUT) aplicado com sucesso na porta SSH ${SSH_PORT}!${RESET}"
fi

# Salva as alterações de forma persistente
netfilter-persistent save
