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

DOMAINS_CONF="${PROJECT_ROOT}/config/domains.conf"
SECRETS_CONF="${PROJECT_ROOT}/config/secrets.conf"
DOVECOT_DIR="${PROJECT_ROOT}/services/dovecot"
DOVECOT_SQL_CONF="${DOVECOT_DIR}/dovecot-sql.conf.ext.example.generated"
DOVECOT_AUTH_FRAGMENT="${DOVECOT_DIR}/dovecot-auth.conf.fragment.example.generated"
DOVECOT_MAIL_FRAGMENT="${DOVECOT_DIR}/dovecot-mail.conf.fragment.example.generated"
DOVECOT_SQL_SUMMARY="${DOVECOT_DIR}/dovecot-sql-summary.txt"

SAVE_CONFIG="${SAVE_CONFIG:-no}"

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

validate_inputs() {
  validate_domain "${PRIMARY_DOMAIN}" || die "invalid PRIMARY_DOMAIN: ${PRIMARY_DOMAIN}"
  validate_space_separated_domains "${DOMAINS}" || die "DOMAINS must contain one or more valid domains"
  validate_email "${DOMAIN_ADMIN_EMAIL}" || die "invalid DOMAIN_ADMIN_EMAIL: ${DOMAIN_ADMIN_EMAIL}"
  validate_space_separated_emails "${INITIAL_MAILBOXES}" || die "INITIAL_MAILBOXES contains one or more invalid email addresses"
  validate_sql_identifier "${DOVECOT_DB_NAME}" || die "invalid DOVECOT_DB_NAME: ${DOVECOT_DB_NAME}"
  validate_sql_identifier "${DOVECOT_DB_USER}" || die "invalid DOVECOT_DB_USER: ${DOVECOT_DB_USER}"
  validate_password_strength_min "${DOVECOT_DB_PASSWORD}" || die "DOVECOT_DB_PASSWORD must be at least 16 characters long"
  validate_mail_location "${DOVECOT_MAIL_LOCATION}" || die "invalid DOVECOT_MAIL_LOCATION: ${DOVECOT_MAIL_LOCATION}"
  validate_numeric_id "${VMAIL_UID}" || die "invalid VMAIL_UID: ${VMAIL_UID}"
  validate_numeric_id "${VMAIL_GID}" || die "invalid VMAIL_GID: ${VMAIL_GID}"
  print -- " ${DOMAINS} " | grep -q " ${PRIMARY_DOMAIN} " || die "PRIMARY_DOMAIN must also appear in DOMAINS"
}

save_configs_if_requested() {
  [ "${SAVE_CONFIG}" = "yes" ] || return 0

  write_kv_config "${DOMAINS_CONF}"     "PRIMARY_DOMAIN="${PRIMARY_DOMAIN}""     "DOMAINS="${DOMAINS}""     "INITIAL_MAILBOXES="${INITIAL_MAILBOXES}""     "DOMAIN_ADMIN_EMAIL="${DOMAIN_ADMIN_EMAIL}""     "POSTFIX_VIRTUAL_TRANSPORT="${POSTFIX_VIRTUAL_TRANSPORT:-dovecot}""     "DOVECOT_MAIL_LOCATION="${DOVECOT_MAIL_LOCATION}""     "VMAIL_UID="${VMAIL_UID}""     "VMAIL_GID="${VMAIL_GID}""

  write_kv_config "${SECRETS_CONF}"     "VULTR_API_KEY="${VULTR_API_KEY:-}""     "BREVO_API_KEY="${BREVO_API_KEY:-}""     "VIRUSTOTAL_API_KEY="${VIRUSTOTAL_API_KEY:-}""     "MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}""     "POSTFIXADMIN_DB_NAME="${POSTFIXADMIN_DB_NAME:-postfixadmin}""     "POSTFIXADMIN_DB_USER="${POSTFIXADMIN_DB_USER:-postfixadmin}""     "POSTFIXADMIN_DB_PASSWORD="${POSTFIXADMIN_DB_PASSWORD:-}""     "POSTFIXADMIN_SETUP_PASSWORD="${POSTFIXADMIN_SETUP_PASSWORD:-}""     "POSTFIX_DB_NAME="${POSTFIX_DB_NAME:-postfixadmin}""     "POSTFIX_DB_USER="${POSTFIX_DB_USER:-postfixadmin}""     "POSTFIX_DB_PASSWORD="${POSTFIX_DB_PASSWORD:-}""     "DOVECOT_DB_NAME="${DOVECOT_DB_NAME}""     "DOVECOT_DB_USER="${DOVECOT_DB_USER}""     "DOVECOT_DB_PASSWORD="${DOVECOT_DB_PASSWORD}""     "ROUNDCUBE_DB_NAME="${ROUNDCUBE_DB_NAME:-roundcube}""     "ROUNDCUBE_DB_USER="${ROUNDCUBE_DB_USER:-roundcube}""     "ROUNDCUBE_DB_PASSWORD="${ROUNDCUBE_DB_PASSWORD:-}""
}

check_commands() {
  require_command mkdir
  require_command cat
  require_command grep
  require_command awk
  require_command doveconf
  require_command dovecot
}

generate_files() {
  mkdir -p "${DOVECOT_DIR}"

  cat > "${DOVECOT_SQL_CONF}" <<EOF
driver = mysql
connect = host=localhost dbname=${DOVECOT_DB_NAME} user=${DOVECOT_DB_USER} password=replace_at_deployment_time
default_pass_scheme = BLF-CRYPT
password_query = SELECT username AS user, password FROM mailbox WHERE username='%u' AND active='1'
user_query = SELECT '${VMAIL_UID}' AS uid, '${VMAIL_GID}' AS gid, '${DOVECOT_MAIL_LOCATION}' AS home
EOF

  cat > "${DOVECOT_AUTH_FRAGMENT}" <<EOF
passdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf.ext
}

userdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf.ext
}
EOF

  cat > "${DOVECOT_MAIL_FRAGMENT}" <<EOF
mail_location = ${DOVECOT_MAIL_LOCATION}
first_valid_uid = ${VMAIL_UID}
last_valid_uid = ${VMAIL_UID}
mail_uid = ${VMAIL_UID}
mail_gid = ${VMAIL_GID}
EOF

  cat > "${DOVECOT_SQL_SUMMARY}" <<EOF
Phase 05 Dovecot SQL summary
Primary domain: ${PRIMARY_DOMAIN}
Hosted domains: ${DOMAINS}
Optional initial mailboxes: ${INITIAL_MAILBOXES}
Dovecot database name: ${DOVECOT_DB_NAME}
Dovecot database user: ${DOVECOT_DB_USER}
Mail location: ${DOVECOT_MAIL_LOCATION}
VMAIL UID: ${VMAIL_UID}
VMAIL GID: ${VMAIL_GID}
EOF
}

main() {
  print_phase_header "PHASE-05" "dovecot authentication and mailbox delivery"
  collect_inputs
  validate_inputs
  save_configs_if_requested
  check_commands
  generate_files
  log_info "phase 05 dovecot authentication and mailbox delivery completed successfully"
  log_info "next step: run ./scripts/phases/phase-05-verify.ksh"
}

main "$@"
