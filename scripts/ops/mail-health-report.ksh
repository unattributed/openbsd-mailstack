#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
MONITOR_LIB="${PROJECT_ROOT}/scripts/lib/monitoring-diagnostics.ksh"
. "${COMMON_LIB}"
. "${MONITOR_LIB}"

MODE="--stdout"
OUT_FILE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --stdout) MODE="--stdout" ;;
    --write)
      shift
      [ "$#" -gt 0 ] || die "--write requires a file path"
      MODE="--write"
      OUT_FILE="$1"
      ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

monitoring_load_config

render_report() {
  cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${MONITORING_HTML_TITLE} health report</title>
<style>
body { font-family: Arial, sans-serif; margin: 1.5rem; }
table { border-collapse: collapse; width: 100%; margin-bottom: 1rem; }
th, td { border: 1px solid #d8d8d8; padding: 0.5rem; text-align: left; }
th { background: #f0f3f5; }
pre { background: #f7f7f7; border: 1px solid #ddd; padding: 1rem; }
</style>
</head>
<body>
<h1>${MONITORING_HTML_TITLE} health report</h1>
<p>generated $(monitoring_now_iso)</p>
<h2>Services</h2>
<table>
<tr><th>Service</th><th>Status</th></tr>
EOF
  for _svc in ${MONITORING_RCCTL_SERVICES}; do
    print -- "<tr><td>$(monitoring_html_escape "${_svc}")</td><td>$(monitoring_html_escape "$(monitoring_rcctl_status "${_svc}")")</td></tr>"
  done
  cat <<EOF
</table>
<h2>TCP listeners</h2>
<table>
<tr><th>Port</th><th>Status</th></tr>
EOF
  for _port in ${MONITORING_TCP_PORTS}; do
    print -- "<tr><td>${_port}</td><td>$(monitoring_html_escape "$(monitoring_tcp_port_status "${_port}")")</td></tr>"
  done
  cat <<EOF
</table>
<h2>Queue and storage</h2>
<table>
<tr><th>Signal</th><th>Value</th></tr>
<tr><td>mail queue depth</td><td>$(monitoring_html_escape "$(monitoring_detect_queue_depth)")</td></tr>
<tr><td>root disk</td><td>$(monitoring_html_escape "$(df -h / 2>/dev/null | awk 'NR==2 {print $5 " used of " $2}')")</td></tr>
<tr><td>/var disk</td><td>$(monitoring_html_escape "$(df -h /var 2>/dev/null | awk 'NR==2 {print $5 " used of " $2}')")</td></tr>
</table>
<h2>Recent logs</h2>
<pre>$(monitoring_html_escape "$(${PROJECT_ROOT}/scripts/ops/monitoring-log-summary.ksh --stdout 2>/dev/null || true)")</pre>
</body>
</html>
EOF
}

if [ "${MODE}" = "--write" ]; then
  ensure_directory "$(dirname -- "${OUT_FILE}")"
  render_report > "${OUT_FILE}"
  print -- "wrote ${OUT_FILE}"
else
  render_report
fi
