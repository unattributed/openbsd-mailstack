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

POSTFIXADMIN_DIR="${PROJECT_ROOT}/services/postfixadmin"
POSTFIXADMIN_CONFIG_EXAMPLE="${POSTFIXADMIN_DIR}/config.local.php.example.generated"
POSTFIXADMIN_SQL_SUMMARY="${POSTFIXADMIN_DIR}/postfixadmin-sql-summary.txt"

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
  prompt_value "POSTFIXADMIN_DB_NAME" "Enter the PostfixAdmin database name" "postfixadmin"
  prompt_value "POSTFIXADMIN_DB_USER" "Enter the PostfixAdmin database username" "postfixadmin"
  prompt_value "POSTFIXADMIN_DB_PASSWORD" "Enter the PostfixAdmin database password"
  prompt_value "POSTFIXADMIN_SETUP_PASSWORD" "Enter the PostfixAdmin setup password"
  prompt_value "MYSQL_ROOT_PASSWORD" "Enter the MariaDB root password"
  prompt_value "INITIAL_MAILBOXES" "Enter optional initial mailbox addresses separated by spaces" "postmaster@${PRIMARY_DOMAIN} abuse@${PRIMARY_DOMAIN}"
}

main() {
  print_phase_header "PHASE-03" "postfixadmin and sql wiring verification"
  collect_inputs

  validate_domain "${PRIMARY_DOMAIN}" && pass "PRIMARY_DOMAIN is valid: ${PRIMARY_DOMAIN}" || fail "PRIMARY_DOMAIN is invalid"
  validate_space_separated_domains "${DOMAINS}" && pass "DOMAINS contains valid domains" || fail "DOMAINS contains invalid domains"
  validate_email "${DOMAIN_ADMIN_EMAIL}" && pass "DOMAIN_ADMIN_EMAIL is valid: ${DOMAIN_ADMIN_EMAIL}" || fail "DOMAIN_ADMIN_EMAIL is invalid"
  validate_space_separated_emails "${INITIAL_MAILBOXES}" && pass "INITIAL_MAILBOXES contains valid email addresses" || fail "INITIAL_MAILBOXES contains invalid email addresses"
  validate_sql_identifier "${POSTFIXADMIN_DB_NAME}" && pass "POSTFIXADMIN_DB_NAME is valid: ${POSTFIXADMIN_DB_NAME}" || fail "POSTFIXADMIN_DB_NAME is invalid"
  validate_sql_identifier "${POSTFIXADMIN_DB_USER}" && pass "POSTFIXADMIN_DB_USER is valid: ${POSTFIXADMIN_DB_USER}" || fail "POSTFIXADMIN_DB_USER is invalid"
  validate_password_strength_min "${POSTFIXADMIN_DB_PASSWORD}" && pass "POSTFIXADMIN_DB_PASSWORD meets minimum length requirement" || fail "POSTFIXADMIN_DB_PASSWORD is too short"
  validate_password_strength_min "${POSTFIXADMIN_SETUP_PASSWORD}" && pass "POSTFIXADMIN_SETUP_PASSWORD meets minimum length requirement" || fail "POSTFIXADMIN_SETUP_PASSWORD is too short"
  validate_password_strength_min "${MYSQL_ROOT_PASSWORD}" && pass "MYSQL_ROOT_PASSWORD meets minimum length requirement" || fail "MYSQL_ROOT_PASSWORD is too short"

  for cmd in mysql grep awk mkdir cat; do
    command_exists "${cmd}" && pass "required command present: ${cmd}" || fail "required command missing: ${cmd}"
  done

  [ -d "${POSTFIXADMIN_DIR}" ] && pass "services/postfixadmin directory exists" || warn "services/postfixadmin directory does not exist yet"
  [ -f "${POSTFIXADMIN_CONFIG_EXAMPLE}" ] && pass "generated PostfixAdmin config example exists" || warn "generated PostfixAdmin config example is missing"
  [ -f "${POSTFIXADMIN_SQL_SUMMARY}" ] && pass "generated SQL summary exists" || warn "generated SQL summary is missing"

  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  print

  [ "${FAIL_COUNT}" -eq 0 ]
}

main "$@"
