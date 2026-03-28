#!/bin/ksh
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MON_DIR="${PROJECT_ROOT}/services/monitoring"
OPS_DIR="${PROJECT_ROOT}/services/ops"

mkdir -p "${MON_DIR}" "${OPS_DIR}"

cat > "${MON_DIR}/monitoring-checklist.example.generated" <<'EOF'
Monitoring checklist
- review rcctl enabled services
- verify smtpd status
- verify dovecot status
- verify nginx status
- verify rspamd status
- verify redis status
- review recent mail logs
- review recent nginx logs
- confirm recent backup artifacts exist
EOF

cat > "${OPS_DIR}/service-review.example.generated" <<'EOF'
#!/bin/ksh
rcctl ls on
rcctl check smtpd || true
rcctl check dovecot || true
rcctl check nginx || true
rcctl check rspamd || true
rcctl check redis || true
netstat -na | egrep '(:25|:465|:587|:993|:443|:80)'
EOF

cat > "${MON_DIR}/daily-report.example.generated" <<'EOF'
Daily report template
- Date:
- Host:
- Service state:
- Log anomalies:
- Backup status:
- TLS status:
- Notes:
EOF

cat > "${MON_DIR}/monitoring-summary.txt" <<EOF
Phase 14 monitoring and reporting baseline generated
EOF

echo "Phase 14 completed"
