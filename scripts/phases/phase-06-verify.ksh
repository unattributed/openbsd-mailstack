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
POSTFIX_DIR="${PROJECT_ROOT}/services/postfix"
DOVECOT_DIR="${PROJECT_ROOT}/services/dovecot"

NGINX_TLS_FRAGMENT="${NGINX_DIR}/tls-server.fragment.example.generated"
NGINX_ACME_EXAMPLE="${NGINX_DIR}/acme-client.example.generated"
POSTFIX_TLS_FRAGMENT="${POSTFIX_DIR}/tls-main.cf.fragment.example.generated"
DOVECOT_TLS_FRAGMENT="${DOVECOT_DIR}/tls.conf.fragment.example.generated"
TLS_SUMMARY="${NGINX_DIR}/tls-summary.txt"

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
  prompt_value "ADMIN_EMAIL" "Enter the administrator email address, example ops@example.com"
  prompt_value "TLS_CERT_MODE" "Enter the TLS certificate mode" "${TLS_CERT_MODE:-single_hostname}"
  prompt_value "TLS_ACME_PROVIDER" "Enter the ACME provider tool" "${TLS_ACME_PROVIDER:-acme-client}"
  prompt_value "TLS_CERT_FQDN" "Enter the certificate FQDN" "${TLS_CERT_FQDN:-${MAIL_HOSTNAME}}"
  prompt_value "TLS_CERT_PATH_FULLCHAIN" "Enter the full chain certificate path" "${TLS_CERT_PATH_FULLCHAIN:-/etc/ssl/${MAIL_HOSTNAME}.fullchain.pem}"
  prompt_value "TLS_CERT_PATH_KEY" "Enter the private key path" "${TLS_CERT_PATH_KEY:-/etc/ssl/private/${MAIL_HOSTNAME}.key}"
}

main() {
  print_phase_header "PHASE-06" "tls and certificate automation verification"
  collect_inputs

  validate_hostname "${MAIL_HOSTNAME}" && pass "MAIL_HOSTNAME is valid: ${MAIL_HOSTNAME}" || fail "MAIL_HOSTNAME is invalid"
  validate_domain "${PRIMARY_DOMAIN}" && pass "PRIMARY_DOMAIN is valid: ${PRIMARY_DOMAIN}" || fail "PRIMARY_DOMAIN is invalid"
  validate_email "${ADMIN_EMAIL}" && pass "ADMIN_EMAIL is valid: ${ADMIN_EMAIL}" || fail "ADMIN_EMAIL is invalid"
  [ "${TLS_CERT_MODE}" = "single_hostname" ] && pass "TLS_CERT_MODE is valid: ${TLS_CERT_MODE}" || fail "TLS_CERT_MODE must be single_hostname"
  [ "${TLS_ACME_PROVIDER}" = "acme-client" ] && pass "TLS_ACME_PROVIDER is valid: ${TLS_ACME_PROVIDER}" || fail "TLS_ACME_PROVIDER must be acme-client"
  validate_hostname "${TLS_CERT_FQDN}" && pass "TLS_CERT_FQDN is valid: ${TLS_CERT_FQDN}" || fail "TLS_CERT_FQDN is invalid"
  [ "${TLS_CERT_FQDN}" = "${MAIL_HOSTNAME}" ] && pass "TLS_CERT_FQDN matches MAIL_HOSTNAME" || fail "TLS_CERT_FQDN must match MAIL_HOSTNAME"
  validate_absolute_path "${TLS_CERT_PATH_FULLCHAIN}" && pass "TLS_CERT_PATH_FULLCHAIN is valid: ${TLS_CERT_PATH_FULLCHAIN}" || fail "TLS_CERT_PATH_FULLCHAIN is invalid"
  validate_absolute_path "${TLS_CERT_PATH_KEY}" && pass "TLS_CERT_PATH_KEY is valid: ${TLS_CERT_PATH_KEY}" || fail "TLS_CERT_PATH_KEY is invalid"

  for cmd in acme-client openssl grep awk mkdir cat; do
    command_exists "${cmd}" && pass "required command present: ${cmd}" || fail "required command missing: ${cmd}"
  done

  [ -f "${NGINX_TLS_FRAGMENT}" ] && pass "generated nginx TLS fragment exists" || warn "generated nginx TLS fragment is missing"
  [ -f "${NGINX_ACME_EXAMPLE}" ] && pass "generated acme-client example exists" || warn "generated acme-client example is missing"
  [ -f "${POSTFIX_TLS_FRAGMENT}" ] && pass "generated Postfix TLS fragment exists" || warn "generated Postfix TLS fragment is missing"
  [ -f "${DOVECOT_TLS_FRAGMENT}" ] && pass "generated Dovecot TLS fragment exists" || warn "generated Dovecot TLS fragment is missing"
  [ -f "${TLS_SUMMARY}" ] && pass "generated TLS summary exists" || warn "generated TLS summary is missing"

  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  print

  [ "${FAIL_COUNT}" -eq 0 ]
}

main "$@"
