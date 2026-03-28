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

POSTFIX_DIR="${PROJECT_ROOT}/services/postfix"
POSTFIX_MAIN_FRAGMENT="${POSTFIX_DIR}/main.cf.fragment.example.generated"
POSTFIX_DOMAINS_MAP="${POSTFIX_DIR}/mysql-virtual-domains.cf.example.generated"
POSTFIX_MAILBOXES_MAP="${POSTFIX_DIR}/mysql-virtual-mailboxes.cf.example.generated"
POSTFIX_ALIASES_MAP="${POSTFIX_DIR}/mysql-virtual-aliases.cf.example.generated"
POSTFIX_SQL_SUMMARY="${POSTFIX_DIR}/postfix-sql-summary.txt"

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

  prompt_value "PRIMARY_DOMAIN" "Enter the primary hosted mail domain, example example.com"
  prompt_value "DOMAINS" "Enter all hosted mail domains separated by spaces, example 'example.com example.net'" "${PRIMARY_DOMAIN}"
  prompt_value "DOMAIN_ADMIN_EMAIL" "Enter the domain administration email address, example ops@example.com" "ops@${PRIMARY_DOMAIN}"
  prompt_value "POSTFIX_DB_NAME" "Enter the Postfix SQL database name" "${POSTFIXADMIN_DB_NAME:-postfixadmin}"
  prompt_value "POSTFIX_DB_USER" "Enter the Postfix SQL username" "${POSTFIXADMIN_DB_USER:-postfixadmin}"
  prompt_value "POSTFIX_DB_PASSWORD" "Enter the Postfix SQL password"
  prompt_value "POSTFIX_VIRTUAL_TRANSPORT" "Enter the Postfix virtual transport value" "${POSTFIX_VIRTUAL_TRANSPORT:-dovecot}"
  prompt_value "INITIAL_MAILBOXES" "Enter optional initial mailbox addresses separated by spaces" "postmaster@${PRIMARY_DOMAIN} abuse@${PRIMARY_DOMAIN}"
}

main() {
  print_phase_header "PHASE-04" "postfix core and sql integration verification"
  collect_inputs

  validate_domain "${PRIMARY_DOMAIN}" && pass "PRIMARY_DOMAIN is valid: ${PRIMARY_DOMAIN}" || fail "PRIMARY_DOMAIN is invalid"
  validate_space_separated_domains "${DOMAINS}" && pass "DOMAINS contains valid domains" || fail "DOMAINS contains invalid domains"
  validate_email "${DOMAIN_ADMIN_EMAIL}" && pass "DOMAIN_ADMIN_EMAIL is valid: ${DOMAIN_ADMIN_EMAIL}" || fail "DOMAIN_ADMIN_EMAIL is invalid"
  validate_space_separated_emails "${INITIAL_MAILBOXES}" && pass "INITIAL_MAILBOXES contains valid email addresses" || fail "INITIAL_MAILBOXES contains invalid email addresses"
  validate_sql_identifier "${POSTFIX_DB_NAME}" && pass "POSTFIX_DB_NAME is valid: ${POSTFIX_DB_NAME}" || fail "POSTFIX_DB_NAME is invalid"
  validate_sql_identifier "${POSTFIX_DB_USER}" && pass "POSTFIX_DB_USER is valid: ${POSTFIX_DB_USER}" || fail "POSTFIX_DB_USER is invalid"
  validate_password_strength_min "${POSTFIX_DB_PASSWORD}" && pass "POSTFIX_DB_PASSWORD meets minimum length requirement" || fail "POSTFIX_DB_PASSWORD is too short"
  validate_transport_name "${POSTFIX_VIRTUAL_TRANSPORT}" && pass "POSTFIX_VIRTUAL_TRANSPORT is valid: ${POSTFIX_VIRTUAL_TRANSPORT}" || fail "POSTFIX_VIRTUAL_TRANSPORT is invalid"

  for cmd in postconf grep awk mkdir cat; do
    command_exists "${cmd}" && pass "required command present: ${cmd}" || fail "required command missing: ${cmd}"
  done

  [ -d "${POSTFIX_DIR}" ] && pass "services/postfix directory exists" || warn "services/postfix directory does not exist yet"
  [ -f "${POSTFIX_MAIN_FRAGMENT}" ] && pass "generated Postfix main.cf fragment exists" || warn "generated Postfix main.cf fragment is missing"
  [ -f "${POSTFIX_DOMAINS_MAP}" ] && pass "generated Postfix domains map exists" || warn "generated Postfix domains map is missing"
  [ -f "${POSTFIX_MAILBOXES_MAP}" ] && pass "generated Postfix mailboxes map exists" || warn "generated Postfix mailboxes map is missing"
  [ -f "${POSTFIX_ALIASES_MAP}" ] && pass "generated Postfix aliases map exists" || warn "generated Postfix aliases map is missing"
  [ -f "${POSTFIX_SQL_SUMMARY}" ] && pass "generated Postfix SQL summary exists" || warn "generated Postfix SQL summary is missing"

  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  print

  [ "${FAIL_COUNT}" -eq 0 ]
}

main "$@"
