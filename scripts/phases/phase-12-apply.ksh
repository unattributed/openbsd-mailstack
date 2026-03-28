#!/bin/ksh
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/services/backup"

mkdir -p "${BACKUP_DIR}"

cat > "${BACKUP_DIR}/backup-encryption.example.generated" <<'EOF'
#!/bin/ksh
tar -czf /backup/mailstack-backup.tgz /etc /var/vmail /var/www
signify -S -s /root/.signify/backup.sec -m /backup/mailstack-backup.tgz
sha256 /backup/mailstack-backup.tgz > /backup/mailstack-backup.sha256
EOF

cat > "${BACKUP_DIR}/backup-manifest.example.generated" <<'EOF'
tar -tzf /backup/mailstack-backup.tgz > /backup/mailstack-backup.manifest
EOF

cat > "${BACKUP_DIR}/backup-verify.example.generated" <<'EOF'
signify -V -p /root/.signify/backup.pub -m /backup/mailstack-backup.tgz
sha256 -c /backup/mailstack-backup.sha256
EOF

cat > "${BACKUP_DIR}/integrity-summary.txt" <<EOF
Phase 12 integrity baseline generated
EOF

echo "Phase 12 completed"
