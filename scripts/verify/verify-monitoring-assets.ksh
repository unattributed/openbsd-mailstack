#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P 2>/dev/null || pwd -P)"

load_monitoring_inputs() {
  for _dir in \
    "${PROJECT_ROOT}/config" \
    "${PROJECT_ROOT}/config/local" \
    "/etc/openbsd-mailstack" \
    "/root/.config/openbsd-mailstack" \
    "${HOME:-/root}/.config/openbsd-mailstack"
  do
    [ -d "${_dir}" ] || continue
    for _f in "${_dir}"/*.conf; do
      [ -f "${_f}" ] || continue
      . "${_f}"
    done
  done
}

load_monitoring_inputs

PROG="${0##*/}"
SITE_ROOT="${SITE_ROOT:-${MONITORING_SITE_ROOT:-/var/www/monitor/site}}"
DATA_ROOT="${DATA_ROOT:-${MONITORING_DATA_ROOT:-/var/www/monitor/data}}"
TREND_ROOT="${TREND_ROOT:-${DATA_ROOT}/trends}"
PFSTAT_ROOT="${PFSTAT_ROOT:-${MONITORING_PFSTAT_ROOT:-/var/www/htdocs/pfstat}}"
HOST_FQDN="${HOST_FQDN:-${MONITORING_SERVER_NAME:-mail.example.com}}"
HOST_IP="${HOST_IP:-${MONITORING_HOST_IP:-127.0.0.1}}"
CHECK_HTTP="${CHECK_HTTP:-${MONITORING_CHECK_HTTP:-0}}"
MONITORING_REQUIRE_RUNTIME_OUTPUT="${MONITORING_REQUIRE_RUNTIME_OUTPUT:-no}"
MAX_ARTIFACT_AGE_MIN="${MAX_ARTIFACT_AGE_MIN:-30}"
MAX_SITE_AGE_MIN="${MAX_SITE_AGE_MIN:-30}"
MAX_TREND_AGE_MIN="${MAX_TREND_AGE_MIN:-45}"
MAX_PFSTAT_AGE_MIN="${MAX_PFSTAT_AGE_MIN:-120}"
FAIL_ON_STALE="${FAIL_ON_STALE:-1}"

FAILS=0
WARNS=0

ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
pass() { print -- "[${PROG}] $(ts) PASS: $*"; }
warn() { print -- "[${PROG}] $(ts) WARN: $*" >&2; WARNS=$((WARNS + 1)); }
fail() { print -- "[${PROG}] $(ts) FAIL: $*" >&2; FAILS=$((FAILS + 1)); }

need_dir() {
  [ -d "$1" ] && pass "directory present: $1" || fail "missing directory: $1"
}

need_file() {
  [ -s "$1" ] && pass "file present: $1" || fail "missing or empty file: $1"
}

file_mtime_epoch() {
  _f="$1"
  [ -e "${_f}" ] || { print -- 0; return 0; }
  if stat -f '%m' "${_f}" >/dev/null 2>&1; then
    stat -f '%m' "${_f}"
  elif stat -c '%Y' "${_f}" >/dev/null 2>&1; then
    stat -c '%Y' "${_f}"
  else
    print -- 0
  fi
}

check_data_age() {
  _f="$1"
  _max="$2"
  _mtime="$(file_mtime_epoch "${_f}")"
  [ "${_mtime}" -gt 0 ] || { fail "unable to read mtime for ${_f}"; return 0; }
  _age=$(( ($(date +%s) - _mtime) / 60 ))
  if [ "${_age}" -le "${_max}" ]; then
    pass "freshness ok: ${_f} age=${_age}m <= ${_max}m"
  elif [ "${FAIL_ON_STALE}" = "1" ]; then
    fail "stale artifact: ${_f} age=${_age}m > ${_max}m"
  else
    warn "stale artifact: ${_f} age=${_age}m > ${_max}m"
  fi
}

check_sensitive_patterns() {
  patt='BEGIN [A-Z ]*PRIVATE KEY|-----BEGIN|AKIA[0-9A-Z]{16}|[Pp]ass(word|wd)[[:space:]]*[:=]|[Ss]ecret[[:space:]]*[:=]|[Tt]oken[[:space:]]*[:=]|[Aa]uthorization:[[:space:]]'
  _matches="$(mktemp /tmp/openbsd-mailstack-monitor.verify.XXXXXX)"
  trap 'rm -f "${_matches}"' EXIT HUP INT TERM
  if command -v rg >/dev/null 2>&1; then
    if rg -n -i -E "${patt}" "${SITE_ROOT}" > "${_matches}" 2>/dev/null; then
      fail "potential sensitive content detected in rendered site"
      sed -n '1,20p' "${_matches}" >&2
    else
      pass "no sensitive pattern matches in rendered site"
    fi
  elif grep -R -n -i -E "${patt}" "${SITE_ROOT}" > "${_matches}" 2>/dev/null; then
    fail "potential sensitive content detected in rendered site"
    sed -n '1,20p' "${_matches}" >&2
  else
    pass "no sensitive pattern matches in rendered site"
  fi
  rm -f "${_matches}"
  trap - EXIT HUP INT TERM
}

check_http_exposure() {
  [ "${CHECK_HTTP}" = "1" ] || return 0
  if ! command -v curl >/dev/null 2>&1; then
    warn "curl not found; HTTP exposure checks skipped"
    return 0
  fi
  _base="https://${HOST_FQDN}/_ops/monitor/"
  _data="https://${HOST_FQDN}/_ops/monitor/data/"
  _index_code="$(curl -sk --resolve "${HOST_FQDN}:443:${HOST_IP}" -o /dev/null -w '%{http_code}' "${_base}" || echo 000)"
  case "${_index_code}" in
    200|301|302) pass "monitor URL reachable (${_index_code}): ${_base}" ;;
    *) fail "monitor URL unhealthy (${_index_code}): ${_base}" ;;
  esac
  _data_code="$(curl -sk --resolve "${HOST_FQDN}:443:${HOST_IP}" -o /dev/null -w '%{http_code}' "${_data}" || echo 000)"
  case "${_data_code}" in
    403|404) pass "monitor data path not publicly readable (${_data_code}): ${_data}" ;;
    *) fail "monitor data path exposure suspected (${_data_code}): ${_data}" ;;
  esac
}

verify_repo_assets() {
  for _file in \
    "${PROJECT_ROOT}/config/monitoring.conf.example" \
    "${PROJECT_ROOT}/scripts/install/install-monitoring-assets.ksh" \
    "${PROJECT_ROOT}/scripts/ops/monitoring-collect.ksh" \
    "${PROJECT_ROOT}/scripts/ops/monitoring-render.ksh" \
    "${PROJECT_ROOT}/scripts/ops/monitoring-run.ksh" \
    "${PROJECT_ROOT}/scripts/verify/verify-monitoring-assets.ksh" \
    "${PROJECT_ROOT}/services/monitoring/README.md" \
    "${PROJECT_ROOT}/services/monitoring/cron/root.cron.fragment.template" \
    "${PROJECT_ROOT}/services/nginx/etc/nginx/templates/ops_monitor.locations.tmpl.template" \
    "${PROJECT_ROOT}/services/system/etc/newsyslog/phase14-managed-block.conf.template" \
    "${PROJECT_ROOT}/docs/install/22-openbsd-native-ops-monitoring-site.md"
  do
    [ -f "${_file}" ] && pass "repo asset present: ${_file}" || fail "repo asset missing: ${_file}"
  done
}

verify_runtime_assets() {
  need_dir "${SITE_ROOT}"
  need_dir "${DATA_ROOT}"
  need_dir "${TREND_ROOT}"

  for _file in \
    "${DATA_ROOT}/latest.kv" \
    "${DATA_ROOT}/latest.json" \
    "${SITE_ROOT}/index.html" \
    "${SITE_ROOT}/host.html" \
    "${SITE_ROOT}/network.html" \
    "${SITE_ROOT}/pf.html" \
    "${SITE_ROOT}/mail.html" \
    "${SITE_ROOT}/rspamd.html" \
    "${SITE_ROOT}/dovecot.html" \
    "${SITE_ROOT}/postfix.html" \
    "${SITE_ROOT}/web.html" \
    "${SITE_ROOT}/dns.html" \
    "${SITE_ROOT}/ids.html" \
    "${SITE_ROOT}/vpn.html" \
    "${SITE_ROOT}/storage.html" \
    "${SITE_ROOT}/backups.html" \
    "${SITE_ROOT}/agent.html" \
    "${SITE_ROOT}/changes.html" \
    "${SITE_ROOT}/sparklines/mail_accepted_48h.svg" \
    "${SITE_ROOT}/sparklines/mail_connect_48h.svg" \
    "${SITE_ROOT}/sparklines/mail_rejected_48h.svg" \
    "${SITE_ROOT}/sparklines/suricata_alerts_48h.svg" \
    "${TREND_ROOT}/mail_accepted_48h.tsv" \
    "${TREND_ROOT}/mail_connect_48h.tsv" \
    "${TREND_ROOT}/mail_rejected_48h.tsv" \
    "${TREND_ROOT}/suricata_alerts_48h.tsv"
  do
    need_file "${_file}"
  done

  _html_count="$(find "${SITE_ROOT}" -type f -name '*.html' | wc -l | tr -d ' ')"
  _svg_count="$(find "${SITE_ROOT}/sparklines" -type f -name '*.svg' 2>/dev/null | wc -l | tr -d ' ')"
  [ "${_html_count}" -ge 10 ] && pass "HTML page count looks healthy (${_html_count})" || fail "insufficient HTML pages (${_html_count})"
  [ "${_svg_count}" -ge 4 ] && pass "sparkline count looks healthy (${_svg_count})" || fail "insufficient sparkline files (${_svg_count})"

  for _file in \
    "${DATA_ROOT}/latest.kv" \
    "${DATA_ROOT}/latest.json" \
    "${SITE_ROOT}/index.html" \
    "${SITE_ROOT}/changes.html"
  do
    check_data_age "${_file}" "${MAX_ARTIFACT_AGE_MIN}"
  done

  for _file in \
    "${TREND_ROOT}/mail_accepted_48h.tsv" \
    "${TREND_ROOT}/mail_connect_48h.tsv" \
    "${TREND_ROOT}/mail_rejected_48h.tsv" \
    "${TREND_ROOT}/suricata_alerts_48h.tsv"
  do
    check_data_age "${_file}" "${MAX_TREND_AGE_MIN}"
  done

  if [ -f "${PFSTAT_ROOT}/states_day.jpg" ]; then
    check_data_age "${PFSTAT_ROOT}/states_day.jpg" "${MAX_PFSTAT_AGE_MIN}"
  else
    warn "pfstat image not present: ${PFSTAT_ROOT}/states_day.jpg"
  fi

  check_sensitive_patterns
  check_http_exposure
}

verify_repo_assets
if [ "${MONITORING_REQUIRE_RUNTIME_OUTPUT}" = "yes" ] || [ -d "${SITE_ROOT}" ] || [ -d "${DATA_ROOT}" ]; then
  verify_runtime_assets
else
  warn "runtime monitoring output not present; runtime checks skipped"
fi

if [ "${FAILS}" -gt 0 ]; then
  print -- "[${PROG}] $(ts) RESULT: FAIL (fails=${FAILS}, warns=${WARNS})" >&2
  exit 1
fi
print -- "[${PROG}] $(ts) RESULT: PASS (fails=${FAILS}, warns=${WARNS})"
