#!/bin/ksh
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OPS_DIR="${PROJECT_ROOT}/services/backup"

mkdir -p "${OPS_DIR}"

cat > "${OPS_DIR}/backup-scope.example.generated" <<EOF
Backup scope:
- /etc
- /etc/ssl
- /etc/ssl/private
- /var/vmail
- MariaDB dumps
EOF

cat > "${OPS_DIR}/backup-script.example.generated" <<'EOF'
#!/bin/ksh
tar -czf /backup/mailstack-backup.tgz /etc /var/vmail /var/www
EOF

cat > "${OPS_DIR}/restore-runbook.example.generated" <<EOF
Restore order:
1. base OS
2. config
3. TLS
4. MariaDB
5. maildirs
EOF

cat > "${OPS_DIR}/dr-summary.txt" <<EOF
Phase 11 DR summary generated
EOF

echo "Phase 11 completed"
