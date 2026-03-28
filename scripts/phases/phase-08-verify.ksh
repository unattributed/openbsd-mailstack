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

NGINX_DIR="${PROJECT_ROOT}/services/nginx"
ROUNDCUBE_DIR="${PROJECT_ROOT}/services/roundcube"
POSTFIXADMIN_DIR="${PROJECT_ROOT}/services/postfixadmin"
RSPAMD_DIR="${PROJECT_ROOT}/services/rspamd"

ROUND_FRAG="${NGINX_DIR}/roundcube-server.fragment.example.generated"
PFA_FRAG="${NGINX_DIR}/postfixadmin-server.fragment.example.generated"
RSPAMD_FRAG="${NGINX_DIR}/rspamd-ui-server.fragment.example.generated"
WEB_SUMMARY="${NGINX_DIR}/web-access-summary.txt"
ROUND_SUMMARY="${ROUNDCUBE_DIR}/roundcube-config-summary.txt"
PFA_SUMMARY="${POSTFIXADMIN_DIR}/postfixadmin-access-summary.txt"
RSPAMD_SUMMARY="${RSPAMD_DIR}/rspamd-ui-access-summary.txt"

FAIL_COUNT=0
WARN_COUNT=0

pass() { print -- "[$(timestamp)] PASS  $*"; }
warn() { print -- "[$(timestamp)] WARN  $*"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { print -- "[$(timestamp)] FAIL  $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

collect_inputs() {
  load_project_config
  prompt_value "MAIL_HOSTNAME" "Enter the public mail hostname, example mail.example.com"
  prompt_value "PRIMARY_DOMAIN" "Enter the primary administrative domain, example example.com"
  prompt_value "ENABLE_WIREGUARD" "Enable WireGuard, yes or no" "${ENABLE_WIREGUARD:-yes}"
  prompt_value "WIREGUARD_INTERFACE" "Enter the WireGuard interface name" "${WIREGUARD_INTERFACE:-wg0}"
  prompt_value "WIREGUARD_SUBNET" "Enter the WireGuard subnet in CIDR notation" "${WIREGUARD_SUBNET:-10.44.0.0/24}"
  prompt_value "WEB_VPN_ONLY" "Restrict web surfaces to VPN only, yes or no" "${WEB_VPN_ONLY:-yes}"
  prompt_value "ROUNDCUBE_ENABLED" "Enable Roundcube, yes or no" "${ROUNDCUBE_ENABLED:-yes}"
  prompt_value "ROUNDCUBE_WEB_HOSTNAME" "Enter the Roundcube web hostname" "${ROUNDCUBE_WEB_HOSTNAME:-${MAIL_HOSTNAME}}"
  prompt_value "POSTFIXADMIN_WEB_HOSTNAME" "Enter the PostfixAdmin web hostname" "${POSTFIXADMIN_WEB_HOSTNAME:-${MAIL_HOSTNAME}}"
  prompt_value "RSPAMD_UI_HOSTNAME" "Enter the Rspamd UI hostname" "${RSPAMD_UI_HOSTNAME:-${MAIL_HOSTNAME}}"
  prompt_value "TLS_CERT_PATH_FULLCHAIN" "Enter the full chain certificate path" "${TLS_CERT_PATH_FULLCHAIN:-/etc/ssl/${MAIL_HOSTNAME}.fullchain.pem}"
  prompt_value "TLS_CERT_PATH_KEY" "Enter the private key path" "${TLS_CERT_PATH_KEY:-/etc/ssl/private/${MAIL_HOSTNAME}.key}"
}

main() {
  print_phase_header "PHASE-08" "webmail and administrative access verification"
  collect_inputs

  validate_hostname "${MAIL_HOSTNAME}" && pass "MAIL_HOSTNAME is valid: ${MAIL_HOSTNAME}" || fail "MAIL_HOSTNAME is invalid"
  validate_domain "${PRIMARY_DOMAIN}" && pass "PRIMARY_DOMAIN is valid: ${PRIMARY_DOMAIN}" || fail "PRIMARY_DOMAIN is invalid"
  validate_yes_no "${ENABLE_WIREGUARD}" && pass "ENABLE_WIREGUARD is valid: ${ENABLE_WIREGUARD}" || fail "ENABLE_WIREGUARD is invalid"
  [ "${ENABLE_WIREGUARD}" = "yes" ] && pass "ENABLE_WIREGUARD matches MVP baseline" || fail "ENABLE_WIREGUARD must be yes"
  validate_interface_name "${WIREGUARD_INTERFACE}" && pass "WIREGUARD_INTERFACE is valid: ${WIREGUARD_INTERFACE}" || fail "WIREGUARD_INTERFACE is invalid"
  validate_cidr_network "${WIREGUARD_SUBNET}" && pass "WIREGUARD_SUBNET is valid: ${WIREGUARD_SUBNET}" || fail "WIREGUARD_SUBNET is invalid"
  validate_yes_no "${WEB_VPN_ONLY}" && pass "WEB_VPN_ONLY is valid: ${WEB_VPN_ONLY}" || fail "WEB_VPN_ONLY is invalid"
  [ "${WEB_VPN_ONLY}" = "yes" ] && pass "WEB_VPN_ONLY matches MVP baseline" || fail "WEB_VPN_ONLY must be yes"
  validate_yes_no "${ROUNDCUBE_ENABLED}" && pass "ROUNDCUBE_ENABLED is valid: ${ROUNDCUBE_ENABLED}" || fail "ROUNDCUBE_ENABLED is invalid"
  validate_hostname "${ROUNDCUBE_WEB_HOSTNAME}" && pass "ROUNDCUBE_WEB_HOSTNAME is valid: ${ROUNDCUBE_WEB_HOSTNAME}" || fail "ROUNDCUBE_WEB_HOSTNAME is invalid"
  validate_hostname "${POSTFIXADMIN_WEB_HOSTNAME}" && pass "POSTFIXADMIN_WEB_HOSTNAME is valid: ${POSTFIXADMIN_WEB_HOSTNAME}" || fail "POSTFIXADMIN_WEB_HOSTNAME is invalid"
  validate_hostname "${RSPAMD_UI_HOSTNAME}" && pass "RSPAMD_UI_HOSTNAME is valid: ${RSPAMD_UI_HOSTNAME}" || fail "RSPAMD_UI_HOSTNAME is invalid"
  validate_absolute_path "${TLS_CERT_PATH_FULLCHAIN}" && pass "TLS_CERT_PATH_FULLCHAIN is valid: ${TLS_CERT_PATH_FULLCHAIN}" || fail "TLS_CERT_PATH_FULLCHAIN is invalid"
  validate_absolute_path "${TLS_CERT_PATH_KEY}" && pass "TLS_CERT_PATH_KEY is valid: ${TLS_CERT_PATH_KEY}" || fail "TLS_CERT_PATH_KEY is invalid"

  for cmd in nginx rcctl grep awk mkdir cat; do
    command_exists "${cmd}" && pass "required command present: ${cmd}" || fail "required command missing: ${cmd}"
  done

  [ -f "${ROUND_FRAG}" ] && pass "generated Roundcube nginx fragment exists" || warn "generated Roundcube nginx fragment is missing"
  [ -f "${PFA_FRAG}" ] && pass "generated PostfixAdmin nginx fragment exists" || warn "generated PostfixAdmin nginx fragment is missing"
  [ -f "${RSPAMD_FRAG}" ] && pass "generated Rspamd UI nginx fragment exists" || warn "generated Rspamd UI nginx fragment is missing"
  [ -f "${WEB_SUMMARY}" ] && pass "generated web access summary exists" || warn "generated web access summary is missing"
  [ -f "${ROUND_SUMMARY}" ] && pass "generated Roundcube summary exists" || warn "generated Roundcube summary is missing"
  [ -f "${PFA_SUMMARY}" ] && pass "generated PostfixAdmin summary exists" || warn "generated PostfixAdmin summary is missing"
  [ -f "${RSPAMD_SUMMARY}" ] && pass "generated Rspamd summary exists" || warn "generated Rspamd summary is missing"

  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  print

  [ "${FAIL_COUNT}" -eq 0 ]
}

main "$@"
