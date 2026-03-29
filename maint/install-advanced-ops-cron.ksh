#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"
CRON_SNIPPET="${PROJECT_ROOT}/services/generated/advanced-ops-root.cron"
cat > "${CRON_SNIPPET}" <<'EOF'
*/15 * * * * /usr/local/sbin/suricata-dump.ksh >> /var/log/suricata-dump.log 2>&1
40 3 * * * /usr/local/sbin/sbom-daily-scan.ksh >> /var/log/sbom-daily.log 2>&1
EOF
print -- "Generated ${CRON_SNIPPET}"
print -- "Review it, then append it to root's crontab if appropriate."
