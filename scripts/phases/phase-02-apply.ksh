#!/bin/ksh
#
# scripts/phases/phase-02-apply.ksh
#
# Public Phase 02 apply script for openbsd-mailstack.
#

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

SECRETS_CONF="${PROJECT_ROOT}/config/secrets.conf"
DOMAINS_CONF="${PROJECT_ROOT}/config/domains.conf"
SAVE_CONFIG="${SAVE_CONFIG:-no}"

usage() {
  cat <<'EOF'
Usage:
  doas ./scripts/phases/phase-02-apply.ksh

Optional environment variables:
  OPENBSD_MAILSTACK_NONINTERACTIVE=1   Disable prompts, fail if values are missing
  SAVE_CONFIG=yes                      Save prompted values into config/secrets.conf
EOF
}

if [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

collect_inputs() {
  load_project_config

  prompt_value "OPENBSD_VERSION" "Enter the supported OpenBSD version for this deployment" "7.8"
  prompt_value "PRIMARY_DOMAIN" "Enter the primary mail domain, example example.com"
  prompt_value "DOMAINS" "Enter the full hosted domain list separated by spaces"
  prompt_value "MYSQL_ROOT_PASSWORD" "Enter the MariaDB root password"
  prompt_value "MAILSTACK_DB_NAME" "Enter the shared mailstack database name" "mailstack"
  prompt_value "MAILSTACK_DB_USER" "Enter the shared mailstack database username" "mailstack"
  prompt_value "MAILSTACK_DB_PASSWORD" "Enter the shared mailstack database password"
  prompt_value "POSTFIXADMIN_DB_NAME" "Enter the PostfixAdmin database name" "postfixadmin"
  prompt_value "POSTFIXADMIN_DB_USER" "Enter the PostfixAdmin database username" "postfixadmin"
  prompt_value "POSTFIXADMIN_DB_PASSWORD" "Enter the PostfixAdmin database password"
  prompt_value "ROUNDCUBE_DB_NAME" "Enter the Roundcube database name" "roundcube"
  prompt_value "ROUNDCUBE_DB_USER" "Enter the Roundcube database username" "roundcube"
  prompt_value "ROUNDCUBE_DB_PASSWORD" "Enter the Roundcube database password"
}

validate_domain_list() {
  for _domain in ${DOMAINS}; do
    validate_domain "${_domain}" || die "invalid domain in DOMAINS list: ${_domain}"
  done
}

validate_inputs() {
  require_valid_domain "PRIMARY_DOMAIN"
  validate_domain_list
  require_valid_identifier "MAILSTACK_DB_NAME"
  require_valid_identifier "MAILSTACK_DB_USER"
  require_valid_identifier "POSTFIXADMIN_DB_NAME"
  require_valid_identifier "POSTFIXADMIN_DB_USER"
  require_valid_identifier "ROUNDCUBE_DB_NAME"
  require_valid_identifier "ROUNDCUBE_DB_USER"
  require_valid_password_value "MYSQL_ROOT_PASSWORD"
  require_valid_password_value "MAILSTACK_DB_PASSWORD"
  require_valid_password_value "POSTFIXADMIN_DB_PASSWORD"
  require_valid_password_value "ROUNDCUBE_DB_PASSWORD"
}

save_config_if_requested() {
  if [ "${SAVE_CONFIG}" != "yes" ]; then
    if is_noninteractive; then
      return 0
    fi
    confirm_yes_no "SAVE_CONFIG" "Save the collected SQL values into config/secrets.conf for reuse" "yes"
  fi

  [ "${SAVE_CONFIG}" = "yes" ] || return 0

  if [ ! -f "${DOMAINS_CONF}" ]; then
    log_info "writing ${DOMAINS_CONF}"
    write_named_config "${DOMAINS_CONF}"       "PRIMARY_DOMAIN" "${PRIMARY_DOMAIN}"       "DOMAINS" "${DOMAINS}"
  fi

  log_info "writing ${SECRETS_CONF}"
  write_named_config "${SECRETS_CONF}"     "VULTR_API_KEY" "${VULTR_API_KEY:-}"     "BREVO_API_KEY" "${BREVO_API_KEY:-}"     "VIRUSTOTAL_API_KEY" "${VIRUSTOTAL_API_KEY:-}"     "MYSQL_ROOT_PASSWORD" "${MYSQL_ROOT_PASSWORD}"     "MAILSTACK_DB_NAME" "${MAILSTACK_DB_NAME}"     "MAILSTACK_DB_USER" "${MAILSTACK_DB_USER}"     "MAILSTACK_DB_PASSWORD" "${MAILSTACK_DB_PASSWORD}"     "POSTFIXADMIN_DB_NAME" "${POSTFIXADMIN_DB_NAME}"     "POSTFIXADMIN_DB_USER" "${POSTFIXADMIN_DB_USER}"     "POSTFIXADMIN_DB_PASSWORD" "${POSTFIXADMIN_DB_PASSWORD}"     "ROUNDCUBE_DB_NAME" "${ROUNDCUBE_DB_NAME}"     "ROUNDCUBE_DB_USER" "${ROUNDCUBE_DB_USER}"     "ROUNDCUBE_DB_PASSWORD" "${ROUNDCUBE_DB_PASSWORD}"

  chmod 600 "${SECRETS_CONF}" || die "failed to set permissions on ${SECRETS_CONF}"
}

check_commands() {
  require_command uname
  require_command awk
  require_command grep
  require_command sed
  require_command rcctl
  require_command pkg_info
}

check_openbsd_baseline() {
  ensure_openbsd
  ensure_openbsd_version "${OPENBSD_VERSION}"
}

check_package_state() {
  if pkg_info 2>/dev/null | grep -Eqi '^mariadb-server|^mariadb-client'; then
    log_info "MariaDB package appears to be installed"
  else
    log_warn "MariaDB package does not appear to be installed yet, later phases will require installation"
  fi
}

check_service_state() {
  _svc="$(detect_mariadb_service_name || true)"
  if [ -n "${_svc}" ]; then
    log_info "detected MariaDB service name: ${_svc}"
    if rcctl check "${_svc}" >/dev/null 2>&1; then
      log_info "MariaDB service ${_svc} is currently running"
    else
      log_warn "MariaDB service ${_svc} exists but is not running"
    fi
  else
    log_warn "no MariaDB service name detected yet through rcctl"
  fi
}

print_summary() {
  _domain_count="$(print -- "${DOMAINS}" | wc -w | awk '{print $1}')"
  print
  print -- "Phase 02 summary"
  print -- "  Primary domain         : ${PRIMARY_DOMAIN}"
  print -- "  Hosted domain count    : ${_domain_count}"
  print -- "  Mailstack DB name      : ${MAILSTACK_DB_NAME}"
  print -- "  Mailstack DB user      : ${MAILSTACK_DB_USER}"
  print -- "  PostfixAdmin DB name   : ${POSTFIXADMIN_DB_NAME}"
  print -- "  PostfixAdmin DB user   : ${POSTFIXADMIN_DB_USER}"
  print -- "  Roundcube DB name      : ${ROUNDCUBE_DB_NAME}"
  print -- "  Roundcube DB user      : ${ROUNDCUBE_DB_USER}"
  print
}

main() {
  print_phase_header "PHASE-02" "mariadb baseline"
  collect_inputs
  validate_inputs
  save_config_if_requested
  check_commands
  check_openbsd_baseline
  check_package_state
  check_service_state
  print_summary
  log_info "phase 02 baseline checks completed successfully"
  log_info "next step: run ./scripts/phases/phase-02-verify.ksh"
}

main "$@"
