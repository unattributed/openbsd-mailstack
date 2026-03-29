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
POSTFIXADMIN_DIR="${PROJECT_ROOT}/services/postfixadmin"
POSTFIXADMIN_CONFIG_EXAMPLE="${POSTFIXADMIN_DIR}/config.local.php.example.generated"
POSTFIXADMIN_SQL_SUMMARY="${POSTFIXADMIN_DIR}/postfixadmin-sql-summary.txt"

SAVE_CONFIG="${SAVE_CONFIG:-no}"

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

validate_inputs() {
  validate_domain "${PRIMARY_DOMAIN}" || die "invalid PRIMARY_DOMAIN: ${PRIMARY_DOMAIN}"
  validate_space_separated_domains "${DOMAINS}" || die "DOMAINS must contain one or more valid domains"
  validate_email "${DOMAIN_ADMIN_EMAIL}" || die "invalid DOMAIN_ADMIN_EMAIL: ${DOMAIN_ADMIN_EMAIL}"
  validate_space_separated_emails "${INITIAL_MAILBOXES}" || die "INITIAL_MAILBOXES contains one or more invalid email addresses"
  validate_sql_identifier "${POSTFIXADMIN_DB_NAME}" || die "invalid POSTFIXADMIN_DB_NAME: ${POSTFIXADMIN_DB_NAME}"
  validate_sql_identifier "${POSTFIXADMIN_DB_USER}" || die "invalid POSTFIXADMIN_DB_USER: ${POSTFIXADMIN_DB_USER}"
  validate_password_strength_min "${POSTFIXADMIN_DB_PASSWORD}" || die "POSTFIXADMIN_DB_PASSWORD must be at least 16 characters long"
  validate_password_strength_min "${POSTFIXADMIN_SETUP_PASSWORD}" || die "POSTFIXADMIN_SETUP_PASSWORD must be at least 16 characters long"
  validate_password_strength_min "${MYSQL_ROOT_PASSWORD}" || die "MYSQL_ROOT_PASSWORD must be at least 16 characters long"
  print -- " ${DOMAINS} " | grep -q " ${PRIMARY_DOMAIN} " || die "PRIMARY_DOMAIN must also appear in DOMAINS"
}

save_configs_if_requested() {
  [ "${SAVE_CONFIG}" = "yes" ] || return 0

  write_named_config "${DOMAINS_CONF}"     "PRIMARY_DOMAIN" "${PRIMARY_DOMAIN}"     "DOMAINS" "${DOMAINS}"     "INITIAL_MAILBOXES" "${INITIAL_MAILBOXES}"     "DOMAIN_ADMIN_EMAIL" "${DOMAIN_ADMIN_EMAIL}"

  write_named_config "${SECRETS_CONF}"     "VULTR_API_KEY" "${VULTR_API_KEY:-}"     "BREVO_API_KEY" "${BREVO_API_KEY:-}"     "VIRUSTOTAL_API_KEY" "${VIRUSTOTAL_API_KEY:-}"     "MYSQL_ROOT_PASSWORD" "${MYSQL_ROOT_PASSWORD}"     "POSTFIXADMIN_DB_NAME" "${POSTFIXADMIN_DB_NAME}"     "POSTFIXADMIN_DB_USER" "${POSTFIXADMIN_DB_USER}"     "POSTFIXADMIN_DB_PASSWORD" "${POSTFIXADMIN_DB_PASSWORD}"     "POSTFIXADMIN_SETUP_PASSWORD" "${POSTFIXADMIN_SETUP_PASSWORD}"     "ROUNDCUBE_DB_NAME" "${ROUNDCUBE_DB_NAME:-roundcube}"     "ROUNDCUBE_DB_USER" "${ROUNDCUBE_DB_USER:-roundcube}"     "ROUNDCUBE_DB_PASSWORD" "${ROUNDCUBE_DB_PASSWORD:-}"
}

check_commands() {
  require_command mkdir
  require_command cat
  require_command grep
  require_command awk
  require_command mysql
}

generate_files() {
  mkdir -p "${POSTFIXADMIN_DIR}"

  cat > "${POSTFIXADMIN_CONFIG_EXAMPLE}" <<EOF
<?php
\$CONF['configured'] = true;
\$CONF['database_type'] = 'mysqli';
\$CONF['database_host'] = 'localhost';
\$CONF['database_user'] = '${POSTFIXADMIN_DB_USER}';
\$CONF['database_password'] = 'replace_at_deployment_time';
\$CONF['database_name'] = '${POSTFIXADMIN_DB_NAME}';
\$CONF['setup_password'] = 'replace_at_deployment_time';
EOF

  cat > "${POSTFIXADMIN_SQL_SUMMARY}" <<EOF
Phase 03 SQL summary
Primary domain: ${PRIMARY_DOMAIN}
Hosted domains: ${DOMAINS}
Optional initial mailboxes: ${INITIAL_MAILBOXES}
PostfixAdmin database name: ${POSTFIXADMIN_DB_NAME}
PostfixAdmin database user: ${POSTFIXADMIN_DB_USER}
EOF
}

main() {
  print_phase_header "PHASE-03" "postfixadmin and sql wiring"
  collect_inputs
  validate_inputs
  save_configs_if_requested
  check_commands
  generate_files
  log_info "phase 03 postfixadmin and sql wiring completed successfully"
  log_info "next step: run ./scripts/phases/phase-03-verify.ksh"
}

main "$@"
