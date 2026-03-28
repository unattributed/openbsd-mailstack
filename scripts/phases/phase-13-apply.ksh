#!/bin/ksh
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/services/backup"
MON_DIR="${PROJECT_ROOT}/services/monitoring"

mkdir -p "${BACKUP_DIR}" "${MON_DIR}"

cat > "${BACKUP_DIR}/offhost-replication.example.generated" <<'EOF'
#!/bin/ksh
# Example only, review before use
scp /backup/mailstack-backup.tgz remote-backup:/srv/mailstack/
scp /backup/mailstack-backup.sha256 remote-backup:/srv/mailstack/
scp /backup/mailstack-backup.manifest remote-backup:/srv/mailstack/
EOF

cat > "${BACKUP_DIR}/restore-drill-checklist.example.generated" <<'EOF'
Restore drill checklist
1. Prepare clean non-production restore target
2. Verify backup signature
3. Verify backup checksum
4. Inspect backup manifest
5. Restore /etc and service config
6. Restore TLS material
7. Restore MariaDB data
8. Restore /var/vmail
9. Start services
10. Run validation checks
EOF

cat > "${MON_DIR}/post-restore-validation.example.generated" <<'EOF'
Post-restore validation
- rcctl check smtpd
- rcctl check dovecot
- rcctl check nginx
- rcctl check rspamd
- verify IMAP login
- verify SMTP submission
- verify test message delivery
- verify webmail access from trusted path
EOF

cat > "${BACKUP_DIR}/phase-13-summary.txt" <<EOF
Phase 13 off-host replication and restore testing baseline generated
EOF

echo "Phase 13 completed"
