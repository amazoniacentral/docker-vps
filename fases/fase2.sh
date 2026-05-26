# --- FASE 2: DESBLOQUEIO E LIMPEZA ---
echo "== Verificando travas de processos (APT/DPKG) =="
fuser -vki /var/lib/dpkg/lock-frontend || true
fuser -vki /var/lib/apt/lists/lock || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
dpkg --configure -a
