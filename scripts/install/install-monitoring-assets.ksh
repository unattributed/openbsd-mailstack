#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
MONITOR_LIB="${PROJECT_ROOT}/scripts/lib/monitoring-diagnostics.ksh"
. "${COMMON_LIB}"
. "${MONITOR_LIB}"

MODE="${1:---dry-run}"
case "${MODE}" in
  --dry-run|--apply) ;;
  *) print -- "usage: $(basename "$0") --dry-run | --apply" >&2; exit 2 ;;
esac

monitoring_load_config

[ "${MODE}" = "--dry-run" ] || [ "$(id -u)" -eq 0 ] || die "this action must run as root"

LIBEXEC_DIR="/usr/local/libexec/openbsd-mailstack/monitoring"
SBIN_DIR="/usr/local/sbin"
EXAMPLE_DIR="/usr/local/share/examples/openbsd-mailstack-monitoring"
TEMPLATE_SRC="${PROJECT_ROOT}/services/nginx/etc/nginx/templates/ops_monitor.locations.tmpl.template"
NEWSYSLOG_TEMPLATE_SRC="${PROJECT_ROOT}/services/system/etc/newsyslog/phase14-managed-block.conf.template"
CRON_TEMPLATE_SRC="${PROJECT_ROOT}/services/monitoring/cron/root.cron.fragment.template"

RUNTIME_SCRIPTS="monitoring-log-summary.ksh rspamd-bayes-stats.ksh monitoring-collect.ksh monitoring-render.ksh mail-health-report.ksh monitoring-run.ksh"
MAINT_SCRIPTS="alert-mail.ksh cron-html-report.ksh detect-services.ksh verify-mailstack.ksh rspamd-bayes-stats.ksh"

run() {
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ $*"
  else
    "$@"
  fi
}

render_ops_template() {
  sed \
    -e "s#__MONITORING_URL_PATH__#${MONITORING_URL_PATH}#g" \
    -e "s#__MONITORING_ALIAS_ROOT__#${MONITORING_NGINX_ALIAS_ROOT}#g" \
    -e "s#__MONITORING_ALLOW_TEMPLATE__#${MONITORING_ALLOW_TEMPLATE}#g" \
    "${TEMPLATE_SRC}"
}

render_newsyslog_template() {
  sed \
    -e "s#__MONITORING_RUN_LOG__#${MONITORING_RUN_LOG}#g" \
    -e "s#__MONITORING_REPORT_LOG__#${MONITORING_REPORT_LOG}#g" \
    "${NEWSYSLOG_TEMPLATE_SRC}"
}

render_cron_template() {
  sed \
    -e "s#__MONITORING_CRON_INTERVAL__#${MONITORING_CRON_INTERVAL_MINUTES}#g" \
    -e "s#__MONITORING_REPORT_MINUTE__#${MONITORING_REPORT_MINUTE}#g" \
    -e "s#__MONITORING_REPORT_HOUR__#${MONITORING_REPORT_HOUR}#g" \
    -e "s#__MONITORING_REPORT_EMAIL__#${MONITORING_REPORT_EMAIL}#g" \
    -e "s#__MONITORING_RUN_LOG__#${MONITORING_RUN_LOG}#g" \
    -e "s#__MONITORING_REPORT_LOG__#${MONITORING_REPORT_LOG}#g" \
    "${CRON_TEMPLATE_SRC}"
}

install_wrapper() {
  _name="$1"
  _target="$2"
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ write wrapper ${SBIN_DIR}/${_name} -> ${_target}"
  else
    cat > "${SBIN_DIR}/${_name}" <<EOF
#!/bin/sh
set -eu
exec ${_target} "\$@"
EOF
    chmod 0555 "${SBIN_DIR}/${_name}"
  fi
}

run install -d -m 0755 "${LIBEXEC_DIR}"
run install -d -m 0755 "${SBIN_DIR}"
run install -d -m 0755 "${EXAMPLE_DIR}"

for _script in ${RUNTIME_SCRIPTS}; do
  run install -m 0555 "${PROJECT_ROOT}/scripts/ops/${_script}" "${LIBEXEC_DIR}/${_script}"
  install_wrapper "openbsd-mailstack-${_script%.ksh}" "${LIBEXEC_DIR}/${_script}"
done

for _script in alert-mail.ksh cron-html-report.ksh detect-services.ksh verify-mailstack.ksh; do
  run install -m 0555 "${PROJECT_ROOT}/maint/${_script}" "${SBIN_DIR}/openbsd-mailstack-${_script%.ksh}"
done

if [ "${MODE}" = "--dry-run" ]; then
  print -- "+ render ${EXAMPLE_DIR}/${MONITORING_NGINX_TEMPLATE_NAME}"
  print -- "+ render ${EXAMPLE_DIR}/phase14-managed-block.conf"
  print -- "+ render ${MONITORING_CRON_SNIPPET_PATH}"
else
  render_ops_template > "${EXAMPLE_DIR}/${MONITORING_NGINX_TEMPLATE_NAME}"
  chmod 0644 "${EXAMPLE_DIR}/${MONITORING_NGINX_TEMPLATE_NAME}"
  render_newsyslog_template > "${EXAMPLE_DIR}/phase14-managed-block.conf"
  chmod 0644 "${EXAMPLE_DIR}/phase14-managed-block.conf"
  if [ "${MONITORING_INSTALL_CRON_SNIPPET}" = "yes" ]; then
    ensure_directory "$(dirname -- "${MONITORING_CRON_SNIPPET_PATH}")"
    render_cron_template > "${MONITORING_CRON_SNIPPET_PATH}"
    chmod 0600 "${MONITORING_CRON_SNIPPET_PATH}"
  fi
fi

if [ "${MONITORING_PATCH_NGINX}" = "yes" ]; then
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ install nginx template to /etc/nginx/templates/${MONITORING_NGINX_TEMPLATE_NAME}"
  else
    render_ops_template > "/etc/nginx/templates/${MONITORING_NGINX_TEMPLATE_NAME}"
    chmod 0644 "/etc/nginx/templates/${MONITORING_NGINX_TEMPLATE_NAME}"
  fi
fi

if [ "${MONITORING_PATCH_NEWSYSLOG}" = "yes" ]; then
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ append managed monitoring block to ${MONITORING_NEWSYSLOG_CONF} if not present"
  else
    _tmp="$(mktemp /tmp/openbsd-mailstack-newsyslog.XXXXXX)"
    cp -f "${MONITORING_NEWSYSLOG_CONF}" "${_tmp}"
    if ! grep -Fq "${MONITORING_NEWSYSLOG_MARKER_BEGIN}" "${_tmp}"; then
      {
        print -- ""
        print -- "${MONITORING_NEWSYSLOG_MARKER_BEGIN}"
        render_newsyslog_template
        print -- "${MONITORING_NEWSYSLOG_MARKER_END}"
      } >> "${_tmp}"
      install -m 0644 "${_tmp}" "${MONITORING_NEWSYSLOG_CONF}"
    fi
    rm -f "${_tmp}"
  fi
fi

if [ "${MONITORING_PATCH_ROOT_CRONTAB}" = "yes" ]; then
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ patch root crontab with ${MONITORING_CRON_SNIPPET_PATH}"
  else
    _tmp_cron="$(mktemp /tmp/openbsd-mailstack-root.cron.XXXXXX)"
    crontab -l > "${_tmp_cron}" 2>/dev/null || true
    if ! grep -Fq 'openbsd-mailstack-monitoring-run' "${_tmp_cron}"; then
      print -- "" >> "${_tmp_cron}"
      render_cron_template >> "${_tmp_cron}"
      crontab "${_tmp_cron}"
    fi
    rm -f "${_tmp_cron}"
  fi
fi

print -- "monitoring assets processed in mode ${MODE}"
