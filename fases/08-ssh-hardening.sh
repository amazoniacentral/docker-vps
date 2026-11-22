# --- FASE 8: ESTABILIDADE E SEGURANÇA DO SSH (MANTENDO ACESSO POR SENHA) ---
echo "=============================================================================="
echo " O QUE ESTE SCRIPT FAZ:"
echo " 1. Garantia de Acesso por Senha (Fallback Seguro):"
echo "    - Mantém 'PasswordAuthentication yes' ativado no sshd_config e em"
echo "      arquivos auxiliares (sshd_config.d) para você nunca ficar preso"
echo "      fora da VPS caso a chave SSH falhe."
echo " 2. Estabilidade de Conexão (Anti-Travamento / KeepAlive):"
echo "    - Configura 'ClientAliveInterval' para manter a sessão SSH ativa e"
echo "      evitar desconexões ou travamentos por inatividade."
echo " 3. Aplicação Segura:"
echo "    - Testa a sintaxe do SSH (sshd -t) antes de reiniciar o serviço, evitando"
echo "      qualquer falha que derrube o daemon SSH."
echo "=============================================================================="

echo "== Configurando SSH com acesso por senha garantido e KeepAlive =="

# 1. Garante explicitamente que o login por senha permanece ATIVO no arquivo principal
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
if ! grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
fi

# 2. Garante o mesmo nos arquivos de override de provedores cloud (ex: GCP, AWS, etc.)
if [ -d /etc/ssh/sshd_config.d ]; then
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true
fi

# 3. Configura KeepAlive para evitar que o terminal congele/caia em conexões longas
sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 60/' /etc/ssh/sshd_config
if ! grep -q "^ClientAliveInterval" /etc/ssh/sshd_config; then
    echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
fi

sed -i 's/^#*ClientAliveCountMax.*/ClientAliveCountMax 5/' /etc/ssh/sshd_config
if ! grep -q "^ClientAliveCountMax" /etc/ssh/sshd_config; then
    echo "ClientAliveCountMax 5" >> /etc/ssh/sshd_config
fi

# 4. Valida a configuração antes de reiniciar para evitar qualquer risco de travar o SSH
if sshd -t; then
    systemctl restart ssh
    echo -e "${GREEN}✅ SSH configurado com sucesso (acesso por senha mantido e KeepAlive ativo)!${RESET}"
else
    echo -e "${RED}❌ Erro detectado na configuração do SSH. O serviço NÃO foi reiniciado para proteger seu acesso.${RESET}"
fi
