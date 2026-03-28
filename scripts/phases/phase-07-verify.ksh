#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing shared library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

RSPAMD_DIR="${PROJECT_ROOT}/services/rspamd"
POSTFIX_DIR="${PROJECT_ROOT}/services/postfix"

RSPAMD_PROXY_FRAGMENT="${RSPAMD_DIR}/worker-proxy.inc.example.generated"
RSPAMD_CONTROLLER_FRAGMENT="${RSPAMD_DIR}/worker-controller.inc.example.generated"
RSPAMD_REDIS_FRAGMENT="${RSPAMD_DIR}/redis.inc.example.generated"
RSPAMD_ANTIVIRUS_FRAGMENT="${RSPAMD_DIR}/antivirus.conf.example.generated"
POSTFIX_MILTER_FRAGMENT="${POSTFIX_DIR}/rspamd-milter.fragment.example.generated"
FILTERING_SUMMARY="${RSPAMD_DIR}/filtering-summary.txt"

FAIL_COUNT=0
WARN_COUNT=0

pass() {
  print -- "[$(timestamp)] PASS  $*"
}

warn() {
  print -- "[$(timestamp)] WARN  $*"
  WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
  print -- "[$(timestamp)] FAIL  $*"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

collect_inputs() {
  load_project_config

  prompt_value "MAIL_HOSTNAME" "Enter the public mail hostname, example mail.example.com"
  prompt_value "PRIMARY_DOMAIN" "Enter the primary administrative domain, example example.com"
  prompt_value "RSPAMD_MILTER_BIND" "Enter the Rspamd milter bind value" "${RSPAMD_MILTER_BIND:-127.0.0.1:11332}"
  prompt_value "RSPAMD_NORMAL_BIND" "Enter the Rspamd normal worker bind value" "${RSPAMD_NORMAL_BIND:-127.0.0.1:11333}"
  prompt_value "RSPAMD_CONTROLLER_BIND" "Enter the Rspamd controller bind value" "${RSPAMD_CONTROLLER_BIND:-127.0.0.1:11334}"
  prompt_value "RSPAMD_REDIS_HOST" "Enter the Redis host for Rspamd" "${RSPAMD_REDIS_HOST:-127.0.0.1}"
  prompt_value "RSPAMD_REDIS_PORT" "Enter the Redis port for Rspamd" "${RSPAMD_REDIS_PORT:-6379}"
  prompt_value "RSPAMD_CLAMAV_ENABLED" "Enable ClamAV integration, yes or no" "${RSPAMD_CLAMAV_ENABLED:-yes}"
}

main() {
  print_phase_header "PHASE-07" "filtering and anti-abuse verification"
  collect_inputs

  validate_hostname "${MAIL_HOSTNAME}" && pass "MAIL_HOSTNAME is valid: ${MAIL_HOSTNAME}" || fail "MAIL_HOSTNAME is invalid"
  validate_domain "${PRIMARY_DOMAIN}" && pass "PRIMARY_DOMAIN is valid: ${PRIMARY_DOMAIN}" || fail "PRIMARY_DOMAIN is invalid"
  validate_host_port "${RSPAMD_MILTER_BIND}" && pass "RSPAMD_MILTER_BIND is valid: ${RSPAMD_MILTER_BIND}" || fail "RSPAMD_MILTER_BIND is invalid"
  validate_host_port "${RSPAMD_NORMAL_BIND}" && pass "RSPAMD_NORMAL_BIND is valid: ${RSPAMD_NORMAL_BIND}" || fail "RSPAMD_NORMAL_BIND is invalid"
  validate_host_port "${RSPAMD_CONTROLLER_BIND}" && pass "RSPAMD_CONTROLLER_BIND is valid: ${RSPAMD_CONTROLLER_BIND}" || fail "RSPAMD_CONTROLLER_BIND is invalid"
  ( validate_hostname "${RSPAMD_REDIS_HOST}" || [ "${RSPAMD_REDIS_HOST}" = "127.0.0.1" ] ) && pass "RSPAMD_REDIS_HOST is valid: ${RSPAMD_REDIS_HOST}" || fail "RSPAMD_REDIS_HOST is invalid"
  validate_numeric_port "${RSPAMD_REDIS_PORT}" && pass "RSPAMD_REDIS_PORT is valid: ${RSPAMD_REDIS_PORT}" || fail "RSPAMD_REDIS_PORT is invalid"
  validate_yes_no "${RSPAMD_CLAMAV_ENABLED}" && pass "RSPAMD_CLAMAV_ENABLED is valid: ${RSPAMD_CLAMAV_ENABLED}" || fail "RSPAMD_CLAMAV_ENABLED is invalid"

  for cmd in rspamadm rspamd grep awk mkdir cat; do
    command_exists "${cmd}" && pass "required command present: ${cmd}" || fail "required command missing: ${cmd}"
  done

  [ -f "${RSPAMD_PROXY_FRAGMENT}" ] && pass "generated Rspamd proxy fragment exists" || warn "generated Rspamd proxy fragment is missing"
  [ -f "${RSPAMD_CONTROLLER_FRAGMENT}" ] && pass "generated Rspamd controller fragment exists" || warn "generated Rspamd controller fragment is missing"
  [ -f "${RSPAMD_REDIS_FRAGMENT}" ] && pass "generated Rspamd redis fragment exists" || warn "generated Rspamd redis fragment is missing"
  [ -f "${RSPAMD_ANTIVIRUS_FRAGMENT}" ] && pass "generated antivirus fragment exists" || warn "generated antivirus fragment is missing"
  [ -f "${POSTFIX_MILTER_FRAGMENT}" ] && pass "generated Postfix milter fragment exists" || warn "generated Postfix milter fragment is missing"
  [ -f "${FILTERING_SUMMARY}" ] && pass "generated filtering summary exists" || warn "generated filtering summary is missing"

  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  print

  [ "${FAIL_COUNT}" -eq 0 ]
}

main "$@"
