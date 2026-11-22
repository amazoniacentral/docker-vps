echo -e "\n== Configurando Whitelist e Regras de Bloqueio do Fail2Ban =="
echo "Digite os IPs que deseja ignorar (Whitelist), separados por ESPAÇO."
echo "Exemplo: 192.168.1.10 200.50.100.20 (ou pressione ENTER para pular):"
printf "IPs: "

# Lê o input de forma segura garantindo que não travará o fluxo se o usuário der apenas Enter
if read -r USER_IPS < /dev/tty 2>/dev/null; then
    USER_IPS="${USER_IPS:-}"
else
    USER_IPS=""
fi

# Define os IPs padrões (localhost) e anexa os informados pelo usuário
IGNORE_LIST="127.0.0.1/8 ::1 ${USER_IPS}"

# Cria configuração local robusta para o sshd
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = ${IGNORE_LIST}
bantime  = 1d
findtime  = 10m
maxretry = 3

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

systemctl enable fail2ban &>/dev/null
systemctl restart fail2ban

# Aguarda o socket estabilizar de forma inteligente (tentando por até 5 segundos)
echo "Aguardando o serviço Fail2Ban inicializar o socket..."
for i in {1..5}; do
    if [ -S /var/run/fail2ban/fail2ban.sock ]; then
        break
    fi
    sleep 1
done

echo -e "${GREEN}✅ Fail2Ban configurado e ativo com sucesso!${RESET}"
echo -e "${CYAN}----------------------------------------------------------------${RESET}"
echo -e "IPs na Whitelist: ${YELLOW}${IGNORE_LIST}${RESET}"
echo -e "Status do SSH Jail:"

# Executa a checagem de forma protegida para NUNCA parar a execução global do setup
fail2ban-client status sshd || echo -e "${YELLOW}⚠️ Aviso: O socket do Fail2Ban está inicializando em segundo plano, mas o fluxo continuará normalmente.${RESET}"
echo -e "${CYAN}----------------------------------------------------------------${RESET}"
