#!/bin/bash

# 1. Instalação do pacote
apt update
apt install fail2ban -y

# 2. Coleta de IPs para Whitelist (Whitelist)
# Usa /dev/tty para garantir que a leitura funcione mesmo via pipe (curl/git)
echo "Digite os IPs que deseja ignorar (Whitelist), separados por ESPAÇO."
echo "Exemplo: 192.168.1.10 200.50.100.20"
printf "IPs: "
read -r USER_IPS < /dev/tty

# Define os IPs padrões (localhost) e anexa os informados pelo usuário
IGNORE_LIST="127.0.0.1/8 ::1 ${USER_IPS}"

# 3. Criar configuração local (para não ser sobrescrita em updates)
# Configurações globais: ban de 24h, janela de 10min, 3 tentativas
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
# IPs ignorados (Lista branca configurada)
ignoreip = ${IGNORE_LIST}

# Tempo de banimento (1 dia)
bantime  = 1d

# Janela de tempo para contar falhas (10 minutos)
findtime  = 10m

# Número máximo de tentativas
maxretry = 3

# 4. Configuração específica para SSH
[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

# 5. Habilitar e reiniciar o serviço
systemctl enable fail2ban
systemctl restart fail2ban

# 6. Mostrar status final
echo "------------------------------------------------"
echo "Fail2Ban instalado e configurado com sucesso!"
echo "IPs na Whitelist: ${IGNORE_LIST}"
echo "Status do SSH Jail:"
fail2ban-client status sshd
echo "------------------------------------------------"
