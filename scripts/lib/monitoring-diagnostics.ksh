#!/bin/ksh
set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing common library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

monitoring_now_iso() {
  date -u "+%Y-%m-%dT%H:%M:%SZ"
}

monitoring_now_stamp() {
  date -u "+%Y%m%dT%H%M%SZ"
}

monitoring_json_escape() {
  print -- "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g'
}

monitoring_html_escape() {
  print -- "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

monitoring_file_mtime_epoch() {
  _path="$1"
  [ -e "${_path}" ] || {
    print -- 0
    return 0
  }
  if stat -f '%m' "${_path}" >/dev/null 2>&1; then
    stat -f '%m' "${_path}"
    return 0
  fi
  if stat -c '%Y' "${_path}" >/dev/null 2>&1; then
    stat -c '%Y' "${_path}"
    return 0
  fi
  print -- 0
}

monitoring_file_age_minutes() {
  _path="$1"
  _mtime="$(monitoring_file_mtime_epoch "${_path}")"
  [ "${_mtime}" -gt 0 ] || {
    print -- -1
    return 0
  }
  _now="$(date +%s)"
  print -- $(( (_now - _mtime) / 60 ))
}

monitoring_rcctl_status() {
  _service="$1"
  if ! command_exists rcctl; then
    print -- unknown
    return 0
  fi
  if rcctl check "${_service}" >/dev/null 2>&1; then
    print -- running
    return 0
  fi
  if rcctl ls on 2>/dev/null | grep -qx "${_service}"; then
    print -- enabled_not_running
    return 0
  fi
  if rcctl ls all 2>/dev/null | grep -qx "${_service}"; then
    print -- installed_not_enabled
    return 0
  fi
  print -- absent
}

monitoring_tcp_port_status() {
  _port="$1"
  if ! command_exists netstat; then
    print -- unknown
    return 0
  fi
  if netstat -na -p tcp 2>/dev/null | awk -v p="${_port}" '$0 ~ "\\." p " " && $0 ~ /LISTEN/ { found = 1 } END { exit(found ? 0 : 1) }'; then
    print -- listening
  else
    print -- closed
  fi
}

monitoring_detect_queue_depth() {
  if ! command_exists mailq; then
    print -- unknown
    return 0
  fi
  mailq 2>/dev/null | awk '/^[A-F0-9]/ { count++ } END { print count + 0 }'
}

monitoring_latest_backup_marker() {
  _root="${BACKUP_ROOT:-/var/backups/openbsd-mailstack}"
  if [ -L "${_root}/latest" ]; then
    print -- "${_root}/latest"
    return 0
  fi
  ls -1dt "${_root}"/* 2>/dev/null | head -n 1 || true
}

monitoring_set_defaults() {
  : "${MONITORING_ENABLED:=yes}"
  : "${MONITORING_SERVER_NAME:=${MAIL_HOSTNAME:-$(hostname -f 2>/dev/null || hostname)}}"
  : "${MONITORING_URL_PATH:=/_ops/monitor/}"
  : "${MONITORING_OUTPUT_ROOT:=/var/www/monitor}"
  : "${MONITORING_SITE_ROOT:=${MONITORING_OUTPUT_ROOT}/site}"
  : "${MONITORING_DATA_ROOT:=${MONITORING_OUTPUT_ROOT}/data}"
  : "${MONITORING_NGINX_ALIAS_ROOT:=/monitor/site/}"
  : "${MONITORING_NGINX_TEMPLATE_NAME:=openbsd-mailstack-ops-monitor.locations.tmpl}"
  : "${MONITORING_NGINX_SERVER_CONF:=/etc/nginx/sites-available/main-ssl.conf}"
  : "${MONITORING_ALLOW_TEMPLATE:=/etc/nginx/templates/control-plane-allow.tmpl}"
  : "${MONITORING_PATCH_NGINX:=no}"
  : "${MONITORING_PATCH_NEWSYSLOG:=no}"
  : "${MONITORING_NEWSYSLOG_CONF:=/etc/newsyslog.conf}"
  : "${MONITORING_NEWSYSLOG_MARKER_BEGIN:=# begin openbsd-mailstack monitoring managed block}"
  : "${MONITORING_NEWSYSLOG_MARKER_END:=# end openbsd-mailstack monitoring managed block}"
  : "${MONITORING_INSTALL_CRON_SNIPPET:=yes}"
  : "${MONITORING_PATCH_ROOT_CRONTAB:=no}"
  : "${MONITORING_CRON_INTERVAL_MINUTES:=5}"
  : "${MONITORING_CRON_SNIPPET_PATH:=/root/.config/openbsd-mailstack/root-cron.monitoring}"
  : "${MONITORING_REPORT_HOUR:=6}"
  : "${MONITORING_REPORT_MINUTE:=15}"
  : "${MONITORING_REPORT_EMAIL:=${ALERT_EMAIL:-ops@example.com}}"
  : "${MONITORING_RUN_LOG:=/var/log/openbsd-mailstack-monitor.log}"
  : "${MONITORING_REPORT_LOG:=/var/log/openbsd-mailstack-cron-report.log}"
  : "${MONITORING_RCCTL_SERVICES:=postfix dovecot nginx rspamd redis clamd freshclam}"
  : "${MONITORING_TCP_PORTS:=25 465 587 993 443 80}"
  : "${MONITORING_LOG_FILES:=/var/log/maillog /var/log/messages /var/log/nginx/error.log /var/log/rspamd/rspamd.log /var/log/clamav/clamd.log /var/log/clamav/freshclam.log}"
  : "${MONITORING_SUMMARY_LOG_LINES:=20}"
  : "${MONITORING_HTML_TITLE:=OpenBSD Mailstack Monitoring}"
  : "${MONITORING_REQUIRE_RUNTIME_OUTPUT:=no}"
  : "${MONITORING_ENABLE_MAIL_QUEUE:=yes}"
  : "${MONITORING_ENABLE_RSPAMD_BAYES:=yes}"
  : "${MONITORING_ENABLE_SITE:=yes}"

  validate_yes_no "${MONITORING_ENABLED}" || die "MONITORING_ENABLED must be yes or no"
  validate_yes_no "${MONITORING_PATCH_NGINX}" || die "MONITORING_PATCH_NGINX must be yes or no"
  validate_yes_no "${MONITORING_PATCH_NEWSYSLOG}" || die "MONITORING_PATCH_NEWSYSLOG must be yes or no"
  validate_yes_no "${MONITORING_INSTALL_CRON_SNIPPET}" || die "MONITORING_INSTALL_CRON_SNIPPET must be yes or no"
  validate_yes_no "${MONITORING_PATCH_ROOT_CRONTAB}" || die "MONITORING_PATCH_ROOT_CRONTAB must be yes or no"
  validate_yes_no "${MONITORING_REQUIRE_RUNTIME_OUTPUT}" || die "MONITORING_REQUIRE_RUNTIME_OUTPUT must be yes or no"
  validate_yes_no "${MONITORING_ENABLE_MAIL_QUEUE}" || die "MONITORING_ENABLE_MAIL_QUEUE must be yes or no"
  validate_yes_no "${MONITORING_ENABLE_RSPAMD_BAYES}" || die "MONITORING_ENABLE_RSPAMD_BAYES must be yes or no"
  validate_yes_no "${MONITORING_ENABLE_SITE}" || die "MONITORING_ENABLE_SITE must be yes or no"
  validate_hostname "${MONITORING_SERVER_NAME}" || die "invalid MONITORING_SERVER_NAME: ${MONITORING_SERVER_NAME}"
  validate_absolute_path "${MONITORING_OUTPUT_ROOT}" || die "invalid MONITORING_OUTPUT_ROOT: ${MONITORING_OUTPUT_ROOT}"
  validate_absolute_path "${MONITORING_SITE_ROOT}" || die "invalid MONITORING_SITE_ROOT: ${MONITORING_SITE_ROOT}"
  validate_absolute_path "${MONITORING_DATA_ROOT}" || die "invalid MONITORING_DATA_ROOT: ${MONITORING_DATA_ROOT}"
  validate_absolute_path "${MONITORING_CRON_SNIPPET_PATH}" || die "invalid MONITORING_CRON_SNIPPET_PATH: ${MONITORING_CRON_SNIPPET_PATH}"
  validate_absolute_path "${MONITORING_RUN_LOG}" || die "invalid MONITORING_RUN_LOG: ${MONITORING_RUN_LOG}"
  validate_absolute_path "${MONITORING_REPORT_LOG}" || die "invalid MONITORING_REPORT_LOG: ${MONITORING_REPORT_LOG}"
  validate_port "${MONITORING_REPORT_HOUR}" >/dev/null 2>&1 || true
  validate_numeric "${MONITORING_CRON_INTERVAL_MINUTES}" || die "MONITORING_CRON_INTERVAL_MINUTES must be numeric"
  [ "${MONITORING_CRON_INTERVAL_MINUTES}" -ge 1 ] && [ "${MONITORING_CRON_INTERVAL_MINUTES}" -le 59 ] || die "MONITORING_CRON_INTERVAL_MINUTES must be between 1 and 59"
  validate_numeric "${MONITORING_REPORT_HOUR}" || die "MONITORING_REPORT_HOUR must be numeric"
  validate_numeric "${MONITORING_REPORT_MINUTE}" || die "MONITORING_REPORT_MINUTE must be numeric"
  [ "${MONITORING_REPORT_HOUR}" -ge 0 ] && [ "${MONITORING_REPORT_HOUR}" -le 23 ] || die "MONITORING_REPORT_HOUR must be between 0 and 23"
  [ "${MONITORING_REPORT_MINUTE}" -ge 0 ] && [ "${MONITORING_REPORT_MINUTE}" -le 59 ] || die "MONITORING_REPORT_MINUTE must be between 0 and 59"
  validate_port_list "${MONITORING_TCP_PORTS}" || die "MONITORING_TCP_PORTS must be a space separated list of TCP ports"
  validate_space_separated_emails "${MONITORING_REPORT_EMAIL}" || die "MONITORING_REPORT_EMAIL must be a valid email or space separated email list"
}

monitoring_load_config() {
  load_project_config
  monitoring_set_defaults
}
