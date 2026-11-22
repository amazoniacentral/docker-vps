# --- FASE 2: DESBLOQUEIO E LIMPEZA ---
echo "=============================================================================="
echo " O QUE ESTE SCRIPT FAZ:"
echo " 1. Destravamento do Gerenciador de Pacotes (APT/DPKG):"
echo "    - Identifica e encerra processos travados em segundo plano que estejam"
echo "      segurando os arquivos de bloqueio do sistema (fuser)."
echo "    - Remove arquivos de trava antigos ou órfãos deixados por instalações"
echo "      anteriores que foram interrompidas abruptamente (rm -f)."
echo "    - Força a reconfiguração de qualquer pacote que tenha ficado pendente"
echo "      ou corrompido (dpkg --configure -a), garantindo um ambiente limpo."
echo "=============================================================================="

echo "== Verificando travas de processos (APT/DPKG) =="
fuser -vki /var/lib/dpkg/lock-frontend || true
fuser -vki /var/lib/apt/lists/lock || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
dpkg --configure -a
