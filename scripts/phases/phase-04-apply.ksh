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
POSTFIX_DIR="${PROJECT_ROOT}/services/postfix"
POSTFIX_MAIN_FRAGMENT="${POSTFIX_DIR}/main.cf.fragment.example.generated"
POSTFIX_DOMAINS_MAP="${POSTFIX_DIR}/mysql-virtual-domains.cf.example.generated"
POSTFIX_MAILBOXES_MAP="${POSTFIX_DIR}/mysql-virtual-mailboxes.cf.example.generated"
POSTFIX_ALIASES_MAP="${POSTFIX_DIR}/mysql-virtual-aliases.cf.example.generated"
POSTFIX_SQL_SUMMARY="${POSTFIX_DIR}/postfix-sql-summary.txt"

SAVE_CONFIG="${SAVE_CONFIG:-no}"

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

validate_inputs() {
  validate_domain "${PRIMARY_DOMAIN}" || die "invalid PRIMARY_DOMAIN: ${PRIMARY_DOMAIN}"
  validate_space_separated_domains "${DOMAINS}" || die "DOMAINS must contain one or more valid domains"
  validate_email "${DOMAIN_ADMIN_EMAIL}" || die "invalid DOMAIN_ADMIN_EMAIL: ${DOMAIN_ADMIN_EMAIL}"
  validate_space_separated_emails "${INITIAL_MAILBOXES}" || die "INITIAL_MAILBOXES contains one or more invalid email addresses"
  validate_sql_identifier "${POSTFIX_DB_NAME}" || die "invalid POSTFIX_DB_NAME: ${POSTFIX_DB_NAME}"
  validate_sql_identifier "${POSTFIX_DB_USER}" || die "invalid POSTFIX_DB_USER: ${POSTFIX_DB_USER}"
  validate_password_strength_min "${POSTFIX_DB_PASSWORD}" || die "POSTFIX_DB_PASSWORD must be at least 16 characters long"
  validate_transport_name "${POSTFIX_VIRTUAL_TRANSPORT}" || die "invalid POSTFIX_VIRTUAL_TRANSPORT: ${POSTFIX_VIRTUAL_TRANSPORT}"
  print -- " ${DOMAINS} " | grep -q " ${PRIMARY_DOMAIN} " || die "PRIMARY_DOMAIN must also appear in DOMAINS"
}

save_configs_if_requested() {
  [ "${SAVE_CONFIG}" = "yes" ] || return 0
  mkdir -p "${CONFIG_DIR}"

  write_named_config "${DOMAINS_CONF}"     "PRIMARY_DOMAIN" "${PRIMARY_DOMAIN}"     "DOMAINS" "${DOMAINS}"     "INITIAL_MAILBOXES" "${INITIAL_MAILBOXES}"     "DOMAIN_ADMIN_EMAIL" "${DOMAIN_ADMIN_EMAIL}"     "POSTFIX_VIRTUAL_TRANSPORT" "${POSTFIX_VIRTUAL_TRANSPORT}"

  write_named_config "${SECRETS_CONF}"     "VULTR_API_KEY" "${VULTR_API_KEY:-}"     "BREVO_API_KEY" "${BREVO_API_KEY:-}"     "VIRUSTOTAL_API_KEY" "${VIRUSTOTAL_API_KEY:-}"     "MYSQL_ROOT_PASSWORD" "${MYSQL_ROOT_PASSWORD:-}"     "POSTFIXADMIN_DB_NAME" "${POSTFIXADMIN_DB_NAME:-postfixadmin}"     "POSTFIXADMIN_DB_USER" "${POSTFIXADMIN_DB_USER:-postfixadmin}"     "POSTFIXADMIN_DB_PASSWORD" "${POSTFIXADMIN_DB_PASSWORD:-}"     "POSTFIXADMIN_SETUP_PASSWORD" "${POSTFIXADMIN_SETUP_PASSWORD:-}"     "POSTFIX_DB_NAME" "${POSTFIX_DB_NAME}"     "POSTFIX_DB_USER" "${POSTFIX_DB_USER}"     "POSTFIX_DB_PASSWORD" "${POSTFIX_DB_PASSWORD}"     "ROUNDCUBE_DB_NAME" "${ROUNDCUBE_DB_NAME:-roundcube}"     "ROUNDCUBE_DB_USER" "${ROUNDCUBE_DB_USER:-roundcube}"     "ROUNDCUBE_DB_PASSWORD" "${ROUNDCUBE_DB_PASSWORD:-}"
}

check_commands() {
  require_command mkdir
  require_command cat
  require_command grep
  require_command awk
  require_command postconf
}

generate_files() {
  mkdir -p "${POSTFIX_DIR}"

  cat > "${POSTFIX_MAIN_FRAGMENT}" <<EOF
virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-domains.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailboxes.cf
virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-aliases.cf
virtual_transport = ${POSTFIX_VIRTUAL_TRANSPORT}
EOF

  cat > "${POSTFIX_DOMAINS_MAP}" <<EOF
user = ${POSTFIX_DB_USER}
password = replace_at_deployment_time
hosts = localhost
dbname = ${POSTFIX_DB_NAME}
query = SELECT domain FROM domain WHERE domain='%s' AND active='1'
EOF

  cat > "${POSTFIX_MAILBOXES_MAP}" <<EOF
user = ${POSTFIX_DB_USER}
password = replace_at_deployment_time
hosts = localhost
dbname = ${POSTFIX_DB_NAME}
query = SELECT maildir FROM mailbox WHERE username='%s' AND active='1'
EOF

  cat > "${POSTFIX_ALIASES_MAP}" <<EOF
user = ${POSTFIX_DB_USER}
password = replace_at_deployment_time
hosts = localhost
dbname = ${POSTFIX_DB_NAME}
query = SELECT goto FROM alias WHERE address='%s' AND active='1'
EOF

  cat > "${POSTFIX_SQL_SUMMARY}" <<EOF
Phase 04 Postfix SQL summary
Primary domain: ${PRIMARY_DOMAIN}
Hosted domains: ${DOMAINS}
Optional initial mailboxes: ${INITIAL_MAILBOXES}
Postfix database name: ${POSTFIX_DB_NAME}
Postfix database user: ${POSTFIX_DB_USER}
Postfix virtual transport: ${POSTFIX_VIRTUAL_TRANSPORT}
EOF
}

main() {
  print_phase_header "PHASE-04" "postfix core and sql integration"
  collect_inputs
  validate_inputs
  save_configs_if_requested
  check_commands
  generate_files
  log_info "phase 04 postfix core and sql integration completed successfully"
  log_info "next step: run ./scripts/phases/phase-04-verify.ksh"
}

main "$@"
