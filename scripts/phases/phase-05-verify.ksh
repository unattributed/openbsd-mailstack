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

DOVECOT_DIR="${PROJECT_ROOT}/services/dovecot"
DOVECOT_SQL_CONF="${DOVECOT_DIR}/dovecot-sql.conf.ext.example.generated"
DOVECOT_AUTH_FRAGMENT="${DOVECOT_DIR}/dovecot-auth.conf.fragment.example.generated"
DOVECOT_MAIL_FRAGMENT="${DOVECOT_DIR}/dovecot-mail.conf.fragment.example.generated"
DOVECOT_SQL_SUMMARY="${DOVECOT_DIR}/dovecot-sql-summary.txt"

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
  prompt_value "DOVECOT_DB_NAME" "Enter the Dovecot SQL database name" "${POSTFIXADMIN_DB_NAME:-postfixadmin}"
  prompt_value "DOVECOT_DB_USER" "Enter the Dovecot SQL username" "${POSTFIXADMIN_DB_USER:-postfixadmin}"
  prompt_value "DOVECOT_DB_PASSWORD" "Enter the Dovecot SQL password"
  prompt_value "DOVECOT_MAIL_LOCATION" "Enter the Dovecot mail location template" "${DOVECOT_MAIL_LOCATION:-maildir:/var/vmail/%d/%n}"
  prompt_value "VMAIL_UID" "Enter the virtual mail UID" "${VMAIL_UID:-2000}"
  prompt_value "VMAIL_GID" "Enter the virtual mail GID" "${VMAIL_GID:-2000}"
  prompt_value "INITIAL_MAILBOXES" "Enter optional initial mailbox addresses separated by spaces" "postmaster@${PRIMARY_DOMAIN} abuse@${PRIMARY_DOMAIN}"
}

main() {
  print_phase_header "PHASE-05" "dovecot authentication and mailbox delivery verification"
  collect_inputs

  validate_domain "${PRIMARY_DOMAIN}" && pass "PRIMARY_DOMAIN is valid: ${PRIMARY_DOMAIN}" || fail "PRIMARY_DOMAIN is invalid"
  validate_space_separated_domains "${DOMAINS}" && pass "DOMAINS contains valid domains" || fail "DOMAINS contains invalid domains"
  validate_email "${DOMAIN_ADMIN_EMAIL}" && pass "DOMAIN_ADMIN_EMAIL is valid: ${DOMAIN_ADMIN_EMAIL}" || fail "DOMAIN_ADMIN_EMAIL is invalid"
  validate_space_separated_emails "${INITIAL_MAILBOXES}" && pass "INITIAL_MAILBOXES contains valid email addresses" || fail "INITIAL_MAILBOXES contains invalid email addresses"
  validate_sql_identifier "${DOVECOT_DB_NAME}" && pass "DOVECOT_DB_NAME is valid: ${DOVECOT_DB_NAME}" || fail "DOVECOT_DB_NAME is invalid"
  validate_sql_identifier "${DOVECOT_DB_USER}" && pass "DOVECOT_DB_USER is valid: ${DOVECOT_DB_USER}" || fail "DOVECOT_DB_USER is invalid"
  validate_password_strength_min "${DOVECOT_DB_PASSWORD}" && pass "DOVECOT_DB_PASSWORD meets minimum length requirement" || fail "DOVECOT_DB_PASSWORD is too short"
  validate_mail_location "${DOVECOT_MAIL_LOCATION}" && pass "DOVECOT_MAIL_LOCATION is valid: ${DOVECOT_MAIL_LOCATION}" || fail "DOVECOT_MAIL_LOCATION is invalid"
  validate_numeric_id "${VMAIL_UID}" && pass "VMAIL_UID is valid: ${VMAIL_UID}" || fail "VMAIL_UID is invalid"
  validate_numeric_id "${VMAIL_GID}" && pass "VMAIL_GID is valid: ${VMAIL_GID}" || fail "VMAIL_GID is invalid"

  for cmd in dovecot doveconf grep awk mkdir cat; do
    command_exists "${cmd}" && pass "required command present: ${cmd}" || fail "required command missing: ${cmd}"
  done

  [ -d "${DOVECOT_DIR}" ] && pass "services/dovecot directory exists" || warn "services/dovecot directory does not exist yet"
  [ -f "${DOVECOT_SQL_CONF}" ] && pass "generated Dovecot SQL config exists" || warn "generated Dovecot SQL config is missing"
  [ -f "${DOVECOT_AUTH_FRAGMENT}" ] && pass "generated Dovecot auth fragment exists" || warn "generated Dovecot auth fragment is missing"
  [ -f "${DOVECOT_MAIL_FRAGMENT}" ] && pass "generated Dovecot mail fragment exists" || warn "generated Dovecot mail fragment is missing"
  [ -f "${DOVECOT_SQL_SUMMARY}" ] && pass "generated Dovecot SQL summary exists" || warn "generated Dovecot SQL summary is missing"

  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  print

  [ "${FAIL_COUNT}" -eq 0 ]
}

main "$@"
