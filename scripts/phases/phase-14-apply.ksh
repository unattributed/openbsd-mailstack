#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
MONITOR_LIB="${PROJECT_ROOT}/scripts/lib/monitoring-diagnostics.ksh"
. "${COMMON_LIB}"
. "${MONITOR_LIB}"

monitoring_load_config

GEN_ROOT="${PROJECT_ROOT}/services/generated/rootfs"
MON_SUMMARY_DIR="${PROJECT_ROOT}/services/generated"
MON_SERVICE_DIR="${PROJECT_ROOT}/services/monitoring"
NGINX_TEMPLATE_SRC="${PROJECT_ROOT}/services/nginx/etc/nginx/templates/ops_monitor.locations.tmpl.template"
NEWSYSLOG_TEMPLATE_SRC="${PROJECT_ROOT}/services/system/etc/newsyslog/phase14-managed-block.conf.template"
CRON_TEMPLATE_SRC="${PROJECT_ROOT}/services/monitoring/cron/root.cron.fragment.template"
RSPAMD_LOGGING_TEMPLATE_SRC="${PROJECT_ROOT}/services/rspamd/etc/rspamd/local.d/logging.inc.template"

ensure_directory "${GEN_ROOT}/etc/nginx/templates"
ensure_directory "${GEN_ROOT}/etc/rspamd/local.d"
ensure_directory "${GEN_ROOT}/usr/local/share/examples/openbsd-mailstack-monitoring"
ensure_directory "${MON_SERVICE_DIR}"

sed \
  -e "s#__MONITORING_URL_PATH__#${MONITORING_URL_PATH}#g" \
  -e "s#__MONITORING_ALIAS_ROOT__#${MONITORING_NGINX_ALIAS_ROOT}#g" \
  -e "s#__MONITORING_ALLOW_TEMPLATE__#${MONITORING_ALLOW_TEMPLATE}#g" \
  "${NGINX_TEMPLATE_SRC}" > "${GEN_ROOT}/etc/nginx/templates/openbsd-mailstack-ops-monitor.locations.tmpl"

sed \
  -e "s#__MONITORING_RUN_LOG__#${MONITORING_RUN_LOG}#g" \
  -e "s#__MONITORING_REPORT_LOG__#${MONITORING_REPORT_LOG}#g" \
  "${NEWSYSLOG_TEMPLATE_SRC}" > "${GEN_ROOT}/etc/newsyslog.phase14-monitoring.conf"

sed \
  -e "s#__MONITORING_CRON_INTERVAL__#${MONITORING_CRON_INTERVAL_MINUTES}#g" \
  -e "s#__MONITORING_REPORT_MINUTE__#${MONITORING_REPORT_MINUTE}#g" \
  -e "s#__MONITORING_REPORT_HOUR__#${MONITORING_REPORT_HOUR}#g" \
  -e "s#__MONITORING_REPORT_EMAIL__#${MONITORING_REPORT_EMAIL}#g" \
  -e "s#__MONITORING_RUN_LOG__#${MONITORING_RUN_LOG}#g" \
  -e "s#__MONITORING_REPORT_LOG__#${MONITORING_REPORT_LOG}#g" \
  "${CRON_TEMPLATE_SRC}" > "${GEN_ROOT}/usr/local/share/examples/openbsd-mailstack-monitoring/root.cron.fragment"

cp -f "${RSPAMD_LOGGING_TEMPLATE_SRC}" "${GEN_ROOT}/etc/rspamd/local.d/logging.inc"

cat > "${MON_SUMMARY_DIR}/monitoring-summary.txt" <<EOF
Phase 14 monitoring and reporting baseline generated
monitoring_enabled=${MONITORING_ENABLED}
monitoring_server_name=${MONITORING_SERVER_NAME}
monitoring_url_path=${MONITORING_URL_PATH}
monitoring_output_root=${MONITORING_OUTPUT_ROOT}
monitoring_site_root=${MONITORING_SITE_ROOT}
monitoring_data_root=${MONITORING_DATA_ROOT}
monitoring_patch_nginx=${MONITORING_PATCH_NGINX}
monitoring_patch_newsyslog=${MONITORING_PATCH_NEWSYSLOG}
monitoring_install_cron_snippet=${MONITORING_INSTALL_CRON_SNIPPET}
monitoring_rcctl_services=${MONITORING_RCCTL_SERVICES}
monitoring_tcp_ports=${MONITORING_TCP_PORTS}
EOF

print -- "Phase 14 completed"
