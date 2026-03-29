#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
MONITOR_LIB="${PROJECT_ROOT}/scripts/lib/monitoring-diagnostics.ksh"
. "${COMMON_LIB}"
. "${MONITOR_LIB}"

OUT_FILE=""
MODE="--stdout"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --stdout) MODE="--stdout" ;;
    --out)
      shift
      [ "$#" -gt 0 ] || die "--out requires a file path"
      OUT_FILE="$1"
      MODE="--out"
      ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

monitoring_load_config

render_summary() {
  print -- "openbsd-mailstack monitoring log summary"
  print -- "timestamp=$(monitoring_now_iso)"
  print -- "server=${MONITORING_SERVER_NAME}"
  print
  for _log in ${MONITORING_LOG_FILES}; do
    print -- "== ${_log} =="
    if [ -f "${_log}" ]; then
      _age="$(monitoring_file_age_minutes "${_log}")"
      _errors="$(grep -Ei 'error|fail|panic|fatal|reject|deferred' "${_log}" 2>/dev/null | tail -n "${MONITORING_SUMMARY_LOG_LINES}" | wc -l | awk '{print $1}')"
      print -- "exists=yes age_minutes=${_age} recent_error_lines=${_errors}"
      tail -n "${MONITORING_SUMMARY_LOG_LINES}" "${_log}" 2>/dev/null || true
    else
      print -- "exists=no"
    fi
    print
  done
}

if [ "${MODE}" = "--out" ]; then
  ensure_directory "$(dirname -- "${OUT_FILE}")"
  render_summary > "${OUT_FILE}"
  print -- "wrote ${OUT_FILE}"
else
  render_summary
fi
