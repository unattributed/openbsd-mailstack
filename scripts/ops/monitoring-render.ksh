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

KV_FILE="${MONITORING_DATA_ROOT}/latest.kv"
PREV_FILE="${MONITORING_DATA_ROOT}/previous.kv"
LOG_SUMMARY_FILE="${MONITORING_DATA_ROOT}/log-summary.txt"
SITE_ROOT="${MONITORING_SITE_ROOT}"
ensure_directory "${SITE_ROOT}"

[ -f "${KV_FILE}" ] || die "missing monitoring data file: ${KV_FILE}"

kv_get() {
  _key="$1"
  _file="${2:-${KV_FILE}}"
  grep -E "^${_key}=" "${_file}" 2>/dev/null | tail -n 1 | sed 's/^[^=]*=//'
}

html_page_begin() {
  _title="$1"
  cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${_title}</title>
<style>
body { font-family: Arial, sans-serif; margin: 2rem auto; max-width: 1100px; line-height: 1.45; color: #1a1a1a; }
a { color: #0b63ce; text-decoration: none; }
a:hover { text-decoration: underline; }
table { border-collapse: collapse; width: 100%; margin: 1rem 0 2rem 0; }
th, td { border: 1px solid #d8d8d8; padding: 0.55rem; text-align: left; vertical-align: top; }
th { background: #f3f5f7; }
.ok { color: #0a6b24; font-weight: bold; }
.warn { color: #9c6500; font-weight: bold; }
.bad { color: #9c0006; font-weight: bold; }
pre { background: #f7f7f7; padding: 1rem; border: 1px solid #ddd; overflow-x: auto; }
.nav { margin-bottom: 1.5rem; }
.nav a { margin-right: 1rem; }
.small { color: #666; font-size: 0.95rem; }
</style>
</head>
<body>
<h1>${_title}</h1>
<div class="nav">
<a href="index.html">overview</a>
<a href="services.html">services</a>
<a href="logs.html">logs</a>
<a href="changes.html">changes</a>
</div>
EOF
}

service_class() {
  case "$1" in
    running|listening|yes) print -- ok ;;
    enabled_not_running|installed_not_enabled|unknown) print -- warn ;;
    *) print -- bad ;;
  esac
}

{
  html_page_begin "${MONITORING_HTML_TITLE}"
  cat <<EOF
<p class="small">Generated $(monitoring_html_escape "$(kv_get timestamp)") for $(monitoring_html_escape "${MONITORING_SERVER_NAME}").</p>
<h2>Overview</h2>
<table>
<tr><th>Signal</th><th>Value</th></tr>
<tr><td>Hostname</td><td>$(monitoring_html_escape "$(kv_get hostname)")</td></tr>
<tr><td>Uptime</td><td>$(monitoring_html_escape "$(kv_get uptime)")</td></tr>
<tr><td>Load average</td><td>$(monitoring_html_escape "$(kv_get load_average)")</td></tr>
<tr><td>Root disk</td><td>$(monitoring_html_escape "$(kv_get disk_root)")</td></tr>
<tr><td>/var disk</td><td>$(monitoring_html_escape "$(kv_get disk_var)")</td></tr>
<tr><td>Services running</td><td>$(monitoring_html_escape "$(kv_get service_running)") of $(monitoring_html_escape "$(kv_get service_count)")</td></tr>
<tr><td>Ports listening</td><td>$(monitoring_html_escape "$(kv_get port_listening)") of $(monitoring_html_escape "$(kv_get port_count)")</td></tr>
<tr><td>Mail queue depth</td><td>$(monitoring_html_escape "$(kv_get mail_queue_depth)")</td></tr>
<tr><td>Latest backup marker</td><td>$(monitoring_html_escape "$(kv_get backup_latest)")</td></tr>
<tr><td>Backup age minutes</td><td>$(monitoring_html_escape "$(kv_get backup_age_minutes)")</td></tr>
</table>
</body>
</html>
EOF
} > "${SITE_ROOT}/index.html"

{
  html_page_begin "${MONITORING_HTML_TITLE} services"
  print -- '<h2>Services</h2>'
  print -- '<table><tr><th>Service</th><th>Status</th></tr>'
  for _svc in ${MONITORING_RCCTL_SERVICES}; do
    _state="$(kv_get service.${_svc})"
    _class="$(service_class "${_state}")"
    print -- "<tr><td>$(monitoring_html_escape "${_svc}")</td><td class=\"${_class}\">$(monitoring_html_escape "${_state}")</td></tr>"
  done
  print -- '</table>'
  print -- '<h2>TCP listeners</h2>'
  print -- '<table><tr><th>Port</th><th>Status</th></tr>'
  for _port in ${MONITORING_TCP_PORTS}; do
    _state="$(kv_get port.${_port})"
    _class="$(service_class "${_state}")"
    print -- "<tr><td>${_port}</td><td class=\"${_class}\">$(monitoring_html_escape "${_state}")</td></tr>"
  done
  print -- '</table></body></html>'
} > "${SITE_ROOT}/services.html"

{
  html_page_begin "${MONITORING_HTML_TITLE} logs"
  print -- '<h2>Log freshness</h2>'
  print -- '<table><tr><th>Log file</th><th>Present</th><th>Age minutes</th></tr>'
  for _log in ${MONITORING_LOG_FILES}; do
    _key="$(print -- "${_log}" | tr '/.-' '_')"
    _present="$(kv_get log.${_key}.present)"
    _age="$(kv_get log.${_key}.age_minutes)"
    _class="$(service_class "${_present}")"
    print -- "<tr><td>$(monitoring_html_escape "${_log}")</td><td class=\"${_class}\">$(monitoring_html_escape "${_present}")</td><td>$(monitoring_html_escape "${_age}")</td></tr>"
  done
  print -- '</table>'
  print -- '<h2>Recent summary</h2>'
  if [ -f "${LOG_SUMMARY_FILE}" ]; then
    print -- '<pre>'
    monitoring_html_escape "$(cat "${LOG_SUMMARY_FILE}")"
    print -- '</pre>'
  else
    print -- '<p>No log summary has been generated yet.</p>'
  fi
  print -- '</body></html>'
} > "${SITE_ROOT}/logs.html"

{
  html_page_begin "${MONITORING_HTML_TITLE} changes"
  print -- '<h2>Changes since previous snapshot</h2>'
  if [ -f "${PREV_FILE}" ]; then
    print -- '<table><tr><th>Key</th><th>Previous</th><th>Current</th></tr>'
    awk -F= '
      NR==FNR { prev[$1]=$0; sub(/^[^=]*=/, "", prev[$1]); keys[$1]=1; next }
      {
        curr=$0; sub(/^[^=]*=/, "", curr); keys[$1]=1; now[$1]=curr
      }
      END {
        for (k in keys) {
          p=(k in prev ? prev[k] : "")
          c=(k in now ? now[k] : "")
          if (p != c) {
            print k "\t" p "\t" c
          }
        }
      }
    ' "${PREV_FILE}" "${KV_FILE}" | sort | while IFS='\t' read -r _key _prev _curr; do
      print -- "<tr><td>$(monitoring_html_escape "${_key}")</td><td>$(monitoring_html_escape "${_prev}")</td><td>$(monitoring_html_escape "${_curr}")</td></tr>"
    done
    print -- '</table>'
  else
    print -- '<p>No previous snapshot is available yet.</p>'
  fi
  print -- '</body></html>'
} > "${SITE_ROOT}/changes.html"

print -- "rendered ${SITE_ROOT}"
