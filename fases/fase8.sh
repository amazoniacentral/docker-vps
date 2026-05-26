# --- FASE 8: SSH E SEGURANÇA ---
echo -e "\n${YELLOW}Deseja bloquear login por senha no SSH? (s/n)${RESET}"
read -p "> " CONFIRM_SSH < /dev/tty
if [[ "$CONFIRM_SSH" =~ ^[Ss]$ ]]; then
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart ssh
fi
