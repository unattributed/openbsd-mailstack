#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${PROJECT_ROOT}/scripts/lib/advanced-gap-rollout.ksh"

advanced_load_config
validate_advanced_inputs

GEN_ROOT="${PROJECT_ROOT}/services/generated/rootfs"
SBOM_GEN="${PROJECT_ROOT}/services/generated/sbom"
ensure_directory "${GEN_ROOT}/etc/suricata"
ensure_directory "${GEN_ROOT}/var/lib/suricata/rules"
ensure_directory "${GEN_ROOT}/usr/local/sbin"
ensure_directory "${GEN_ROOT}/etc/examples/openbsd-mailstack"
ensure_directory "${GEN_ROOT}/etc/nginx/templates"
ensure_directory "${GEN_ROOT}/etc/rc.d"
ensure_directory "${GEN_ROOT}/etc/sogo"
ensure_directory "${SBOM_GEN}"

SURICATA_HOME_NET_LIST="$(print -- "${SURICATA_HOME_NETS}" | awk '{$1=$1; gsub(/ /,",",$0); print $0}')"
render_template_file "${PROJECT_ROOT}/services/suricata/etc/suricata/suricata.yaml.template" "${GEN_ROOT}/etc/suricata/suricata.yaml"   "SURICATA_HOME_NET_LIST=${SURICATA_HOME_NET_LIST}"   "SURICATA_RULE_DIR=${SURICATA_RULE_DIR}"   "SURICATA_LOG_DIR=${SURICATA_LOG_DIR}"   "SURICATA_INTERFACE=${SURICATA_INTERFACE}"   "SURICATA_CAPTURE_FILTER=${SURICATA_CAPTURE_FILTER}"
render_template_file "${PROJECT_ROOT}/services/suricata/etc/suricata/threshold.config.template" "${GEN_ROOT}/etc/suricata/threshold.config"
render_template_file "${PROJECT_ROOT}/services/suricata/etc/suricata/local.rules.template" "${GEN_ROOT}/var/lib/suricata/rules/local.rules"   "PUBLIC_IP=${PUBLIC_IP}"
cp -f "${PROJECT_ROOT}/scripts/ops/suricata-dump.ksh" "${GEN_ROOT}/usr/local/sbin/suricata-dump.ksh"
cp -f "${PROJECT_ROOT}/scripts/ops/suricata-eve2pf.ksh" "${GEN_ROOT}/usr/local/sbin/suricata-eve2pf.ksh"
chmod 0555 "${GEN_ROOT}/usr/local/sbin/suricata-dump.ksh" "${GEN_ROOT}/usr/local/sbin/suricata-eve2pf.ksh"
cat > "${GEN_ROOT}/etc/examples/openbsd-mailstack/suricata.env" <<EOF
SURICATA_INTERFACE="${SURICATA_INTERFACE}"
SURICATA_CAPTURE_FILTER="${SURICATA_CAPTURE_FILTER}"
SURICATA_DASHBOARD_ROOT="${SURICATA_DASHBOARD_ROOT}"
SURICATA_EVE2PF_MODE="${SURICATA_EVE2PF_MODE}"
EOF

render_template_file "${PROJECT_ROOT}/services/brevo/usr/local/sbin/brevo_webhook.py.template" "${GEN_ROOT}/usr/local/sbin/brevo_webhook.py"
chmod 0555 "${GEN_ROOT}/usr/local/sbin/brevo_webhook.py"
render_template_file "${PROJECT_ROOT}/services/brevo/etc/rc.d/brevo_webhook.template" "${GEN_ROOT}/etc/rc.d/brevo_webhook"
chmod 0555 "${GEN_ROOT}/etc/rc.d/brevo_webhook"
render_template_file "${PROJECT_ROOT}/services/brevo/etc/nginx/templates/brevo_webhook.locations.tmpl.template" "${GEN_ROOT}/etc/nginx/templates/${BREVO_WEBHOOK_NGINX_TEMPLATE_NAME}"   "BREVO_WEBHOOK_URL_PATH=${BREVO_WEBHOOK_URL_PATH}"   "BREVO_WEBHOOK_LISTEN_ADDR=${BREVO_WEBHOOK_LISTEN_ADDR}"   "BREVO_WEBHOOK_LISTEN_PORT=${BREVO_WEBHOOK_LISTEN_PORT}"   "MONITORING_ALLOW_TEMPLATE=/etc/nginx/templates/control-plane-allow.tmpl"
render_template_file "${PROJECT_ROOT}/services/brevo/etc/examples/brevo-webhook.env.template" "${GEN_ROOT}/etc/examples/openbsd-mailstack/brevo-webhook.env"   "BREVO_WEBHOOK_LOG_PATH=${BREVO_WEBHOOK_LOG_PATH}"   "BREVO_WEBHOOK_STATE_PATH=${BREVO_WEBHOOK_STATE_PATH}"   "BREVO_WEBHOOK_LISTEN_ADDR=${BREVO_WEBHOOK_LISTEN_ADDR}"   "BREVO_WEBHOOK_LISTEN_PORT=${BREVO_WEBHOOK_LISTEN_PORT}"   "BREVO_WEBHOOK_ALERT_EMAIL=${BREVO_WEBHOOK_ALERT_EMAIL}"

render_template_file "${PROJECT_ROOT}/services/sogo/etc/sogo/sogo.conf.template" "${GEN_ROOT}/etc/sogo/sogo.conf"   "SOGO_LISTEN_ADDR=${SOGO_LISTEN_ADDR}"   "SOGO_LISTEN_PORT=${SOGO_LISTEN_PORT}"   "SOGO_TIMEZONE=${SOGO_TIMEZONE}"   "SOGO_LANGUAGE=${SOGO_LANGUAGE}"   "SOGO_MAIL_DOMAIN=${SOGO_MAIL_DOMAIN}"   "SOGO_DB_USER=${SOGO_DB_USER}"   "SOGO_DB_PASS=${SOGO_DB_PASS}"   "SOGO_DB_NAME=${SOGO_DB_NAME}"
render_template_file "${PROJECT_ROOT}/services/sogo/etc/nginx/templates/sogo.locations.tmpl.template" "${GEN_ROOT}/etc/nginx/templates/openbsd-mailstack-sogo.locations.tmpl"   "SOGO_BASE_PATH=${SOGO_BASE_PATH}"   "SOGO_LISTEN_ADDR=${SOGO_LISTEN_ADDR}"   "SOGO_LISTEN_PORT=${SOGO_LISTEN_PORT}"   "MONITORING_ALLOW_TEMPLATE=/etc/nginx/templates/control-plane-allow.tmpl"
render_template_file "${PROJECT_ROOT}/services/sogo/etc/examples/sogo-db.env.template" "${GEN_ROOT}/etc/examples/openbsd-mailstack/sogo-db.env"   "SOGO_DB_NAME=${SOGO_DB_NAME}"   "SOGO_DB_USER=${SOGO_DB_USER}"   "SOGO_DB_PASS=${SOGO_DB_PASS}"   "SOGO_MAIL_DOMAIN=${SOGO_MAIL_DOMAIN}"

cat > "${SBOM_GEN}/README.txt" <<EOF
SBOM runtime outputs are generated here by phase 17 and optional SBOM cron jobs.
scanner_mode=${SBOM_SCANNER_MODE}
report_email=${SBOM_REPORT_EMAIL}
EOF

cat > "${PROJECT_ROOT}/services/generated/advanced-gap-summary.txt" <<EOF
Phase 17 advanced optional integrations and gap closures generated
enable_suricata=${ENABLE_SURICATA}
enable_brevo_webhook=${ENABLE_BREVO_WEBHOOK}
enable_sogo=${ENABLE_SOGO}
enable_sbom=${ENABLE_SBOM}
sbom_scanner_mode=${SBOM_SCANNER_MODE}
EOF

print -- "Phase 17 advanced assets rendered"
