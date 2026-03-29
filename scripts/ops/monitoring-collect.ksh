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

[ "${MONITORING_ENABLED}" = "yes" ] || {
  print -- "monitoring disabled by configuration"
  exit 0
}

ensure_directory "${MONITORING_DATA_ROOT}"
ensure_directory "${MONITORING_DATA_ROOT}/snapshots"

STAMP="$(monitoring_now_stamp)"
TS_ISO="$(monitoring_now_iso)"
KV_FILE="${MONITORING_DATA_ROOT}/latest.kv"
JSON_FILE="${MONITORING_DATA_ROOT}/latest.json"
PREV_FILE="${MONITORING_DATA_ROOT}/previous.kv"
SNAP_KV="${MONITORING_DATA_ROOT}/snapshots/${STAMP}.kv"
SNAP_JSON="${MONITORING_DATA_ROOT}/snapshots/${STAMP}.json"
TMP_KV="$(mktemp /tmp/openbsd-mailstack-monitoring.kv.XXXXXX)"
trap 'rm -f "${TMP_KV}"' EXIT HUP INT TERM

if [ -f "${KV_FILE}" ]; then
  cp -f "${KV_FILE}" "${PREV_FILE}"
fi

print -- "timestamp=${TS_ISO}" >> "${TMP_KV}"
print -- "stamp=${STAMP}" >> "${TMP_KV}"
print -- "server_name=${MONITORING_SERVER_NAME}" >> "${TMP_KV}"
print -- "url_path=${MONITORING_URL_PATH}" >> "${TMP_KV}"
print -- "hostname=$(hostname -f 2>/dev/null || hostname)" >> "${TMP_KV}"
print -- "uptime=$(uptime 2>/dev/null | sed 's/[[:space:]]\+/ /g')" >> "${TMP_KV}"
print -- "load_average=$(uptime 2>/dev/null | awk -F'load averages?: ' 'NF > 1 {print $2}')" >> "${TMP_KV}"
print -- "disk_root=$(df -h / 2>/dev/null | awk 'NR==2 {print $5 " used of " $2}')" >> "${TMP_KV}"
print -- "disk_var=$(df -h /var 2>/dev/null | awk 'NR==2 {print $5 " used of " $2}')" >> "${TMP_KV}"

if [ "${MONITORING_ENABLE_MAIL_QUEUE}" = "yes" ]; then
  print -- "mail_queue_depth=$(monitoring_detect_queue_depth)" >> "${TMP_KV}"
fi

_latest_backup="$(monitoring_latest_backup_marker)"
print -- "backup_latest=${_latest_backup}" >> "${TMP_KV}"
if [ -n "${_latest_backup}" ]; then
  print -- "backup_age_minutes=$(monitoring_file_age_minutes "${_latest_backup}")" >> "${TMP_KV}"
fi

_service_count=0
_service_running=0
for _svc in ${MONITORING_RCCTL_SERVICES}; do
  _state="$(monitoring_rcctl_status "${_svc}")"
  print -- "service.${_svc}=${_state}" >> "${TMP_KV}"
  _service_count=$((_service_count + 1))
  [ "${_state}" = "running" ] && _service_running=$((_service_running + 1))
done
print -- "service_count=${_service_count}" >> "${TMP_KV}"
print -- "service_running=${_service_running}" >> "${TMP_KV}"

_port_count=0
_port_listening=0
for _port in ${MONITORING_TCP_PORTS}; do
  _state="$(monitoring_tcp_port_status "${_port}")"
  print -- "port.${_port}=${_state}" >> "${TMP_KV}"
  _port_count=$((_port_count + 1))
  [ "${_state}" = "listening" ] && _port_listening=$((_port_listening + 1))
done
print -- "port_count=${_port_count}" >> "${TMP_KV}"
print -- "port_listening=${_port_listening}" >> "${TMP_KV}"

for _log in ${MONITORING_LOG_FILES}; do
  _key="$(print -- "${_log}" | tr '/.-' '_')"
  if [ -f "${_log}" ]; then
    print -- "log.${_key}.present=yes" >> "${TMP_KV}"
    print -- "log.${_key}.age_minutes=$(monitoring_file_age_minutes "${_log}")" >> "${TMP_KV}"
  else
    print -- "log.${_key}.present=no" >> "${TMP_KV}"
  fi
done

if [ "${MONITORING_ENABLE_RSPAMD_BAYES}" = "yes" ] && [ -x "${PROJECT_ROOT}/scripts/ops/rspamd-bayes-stats.ksh" ]; then
  _bayes="$(${PROJECT_ROOT}/scripts/ops/rspamd-bayes-stats.ksh 2>/dev/null || true)"
  if [ -n "${_bayes}" ]; then
    print -- "rspamd_bayes_summary=$(print -- "${_bayes}" | tr '\n' ';' | sed 's/;$/\n/')" >> "${TMP_KV}"
  fi
fi

cp -f "${TMP_KV}" "${KV_FILE}"
cp -f "${TMP_KV}" "${SNAP_KV}"

{
  print -- "{"
  awk -F= '
    BEGIN { first = 1 }
    {
      key = $1
      sub(/^[^=]*=/, "", $0)
      val = $0
      gsub(/\\/, "\\\\", key)
      gsub(/"/, "\\\"", key)
      gsub(/\\/, "\\\\", val)
      gsub(/"/, "\\\"", val)
      if (!first) print ","
      printf "  \"%s\": \"%s\"", key, val
      first = 0
    }
    END { print "" }
  ' "${TMP_KV}"
  print -- "}"
} > "${JSON_FILE}"
cp -f "${JSON_FILE}" "${SNAP_JSON}"

print -- "wrote ${KV_FILE} and ${JSON_FILE}"
