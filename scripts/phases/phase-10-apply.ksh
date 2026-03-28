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

SYSTEM_CONF="${PROJECT_ROOT}/config/system.conf"
OPS_DIR="${PROJECT_ROOT}/services/ops"
BACKUP_DIR="${PROJECT_ROOT}/services/backup"
MON_DIR="${PROJECT_ROOT}/services/monitoring"

HEALTHCHECK="${OPS_DIR}/healthcheck.example.generated"
RCCTL_REVIEW="${OPS_DIR}/rcctl-review.example.generated"
BACKUP_PLAN="${BACKUP_DIR}/backup-plan.example.generated"
LOG_SUMMARY="${MON_DIR}/log-summary.example.generated"
OPS_SUMMARY="${OPS_DIR}/operations-summary.txt"

SAVE_CONFIG="${SAVE_CONFIG:-no}"

collect_inputs() {
  load_project_config
  prompt_value "MAIL_HOSTNAME" "Enter the public mail hostname, example mail.example.com"
  prompt_value "ADMIN_EMAIL" "Enter the administrator email address, example ops@example.com"
  prompt_value "ALERT_EMAIL" "Enter the operational alert email address" "${ALERT_EMAIL:-${ADMIN_EMAIL}}"
  prompt_value "OPS_BACKUP_MODE" "Enter the backup mode" "${OPS_BACKUP_MODE:-local}"
  prompt_value "OPS_RETENTION_DAYS" "Enter the retention period in days" "${OPS_RETENTION_DAYS:-14}"
  prompt_value "OPS_ENABLE_ALERTS" "Enable alerts, yes or no" "${OPS_ENABLE_ALERTS:-yes}"
  prompt_value "OPS_ENABLE_HEALTHCHECKS" "Enable health checks, yes or no" "${OPS_ENABLE_HEALTHCHECKS:-yes}"
  prompt_value "OPS_ENABLE_LOG_SUMMARY" "Enable log summary generation, yes or no" "${OPS_ENABLE_LOG_SUMMARY:-yes}"
}

validate_inputs() {
  validate_hostname "${MAIL_HOSTNAME}" || die "invalid MAIL_HOSTNAME: ${MAIL_HOSTNAME}"
  validate_email "${ADMIN_EMAIL}" || die "invalid ADMIN_EMAIL: ${ADMIN_EMAIL}"
  validate_email "${ALERT_EMAIL}" || die "invalid ALERT_EMAIL: ${ALERT_EMAIL}"
  validate_mode_word "${OPS_BACKUP_MODE}" || die "invalid OPS_BACKUP_MODE: ${OPS_BACKUP_MODE}"
  validate_numeric "${OPS_RETENTION_DAYS}" || die "invalid OPS_RETENTION_DAYS: ${OPS_RETENTION_DAYS}"
  validate_yes_no "${OPS_ENABLE_ALERTS}" || die "OPS_ENABLE_ALERTS must be yes or no"
  validate_yes_no "${OPS_ENABLE_HEALTHCHECKS}" || die "OPS_ENABLE_HEALTHCHECKS must be yes or no"
  validate_yes_no "${OPS_ENABLE_LOG_SUMMARY}" || die "OPS_ENABLE_LOG_SUMMARY must be yes or no"
}

save_configs_if_requested() {
  [ "${SAVE_CONFIG}" = "yes" ] || return 0
  write_kv_config "${SYSTEM_CONF}"     "OPENBSD_VERSION="${OPENBSD_VERSION:-7.8}""     "MAIL_HOSTNAME="${MAIL_HOSTNAME}""     "PRIMARY_DOMAIN="${PRIMARY_DOMAIN:-example.com}""     "ADMIN_EMAIL="${ADMIN_EMAIL}""     "ALERT_EMAIL="${ALERT_EMAIL}""     "PUBLIC_IPV4="${PUBLIC_IPV4:-203.0.113.10}""     "TIMEZONE="${TIMEZONE:-UTC}""     "TLS_CERT_MODE="${TLS_CERT_MODE:-single_hostname}""     "TLS_ACME_PROVIDER="${TLS_ACME_PROVIDER:-acme-client}""     "TLS_CERT_FQDN="${TLS_CERT_FQDN:-${MAIL_HOSTNAME}}""     "TLS_CERT_PATH_FULLCHAIN="${TLS_CERT_PATH_FULLCHAIN:-/etc/ssl/${MAIL_HOSTNAME}.fullchain.pem}""     "TLS_CERT_PATH_KEY="${TLS_CERT_PATH_KEY:-/etc/ssl/private/${MAIL_HOSTNAME}.key}""     "ROUNDCUBE_ENABLED="${ROUNDCUBE_ENABLED:-yes}""     "ROUNDCUBE_WEB_HOSTNAME="${ROUNDCUBE_WEB_HOSTNAME:-${MAIL_HOSTNAME}}""     "POSTFIXADMIN_WEB_HOSTNAME="${POSTFIXADMIN_WEB_HOSTNAME:-${MAIL_HOSTNAME}}""     "RSPAMD_UI_HOSTNAME="${RSPAMD_UI_HOSTNAME:-${MAIL_HOSTNAME}}""     "OPS_BACKUP_MODE="${OPS_BACKUP_MODE}""     "OPS_RETENTION_DAYS="${OPS_RETENTION_DAYS}""     "OPS_ENABLE_ALERTS="${OPS_ENABLE_ALERTS}""     "OPS_ENABLE_HEALTHCHECKS="${OPS_ENABLE_HEALTHCHECKS}""     "OPS_ENABLE_LOG_SUMMARY="${OPS_ENABLE_LOG_SUMMARY}""
}

check_commands() {
  require_command mkdir
  require_command cat
  require_command grep
  require_command awk
  require_command rcctl
  require_command tar
  require_command gzip
}

generate_files() {
  mkdir -p "${OPS_DIR}" "${BACKUP_DIR}" "${MON_DIR}"

  cat > "${HEALTHCHECK}" <<EOF
#!/bin/ksh
rcctl check smtpd || true
rcctl check dovecot || true
rcctl check nginx || true
rcctl check redis || true
rcctl check rspamd || true
EOF

  cat > "${RCCTL_REVIEW}" <<EOF
rcctl ls on
rcctl get smtpd status || true
rcctl get dovecot status || true
rcctl get nginx status || true
rcctl get rspamd status || true
EOF

  cat > "${BACKUP_PLAN}" <<EOF
Backup plan guidance
Host: ${MAIL_HOSTNAME}
Mode: ${OPS_BACKUP_MODE}
Retention days: ${OPS_RETENTION_DAYS}

Suggested backup targets:
- /etc
- /etc/ssl
- /etc/ssl/private
- /var/vmail
- MariaDB dumps
- /var/www
- operational config rendered from this repo
EOF

  cat > "${LOG_SUMMARY}" <<EOF
Log summary guidance
Host: ${MAIL_HOSTNAME}
Enabled: ${OPS_ENABLE_LOG_SUMMARY}

Suggested review targets:
- /var/log/maillog
- /var/log/messages
- /var/log/nginx/*
- /var/log/rspamd/*
EOF

  cat > "${OPS_SUMMARY}" <<EOF
Phase 10 operations summary
MAIL_HOSTNAME: ${MAIL_HOSTNAME}
ADMIN_EMAIL: ${ADMIN_EMAIL}
ALERT_EMAIL: ${ALERT_EMAIL}
OPS_BACKUP_MODE: ${OPS_BACKUP_MODE}
OPS_RETENTION_DAYS: ${OPS_RETENTION_DAYS}
OPS_ENABLE_ALERTS: ${OPS_ENABLE_ALERTS}
OPS_ENABLE_HEALTHCHECKS: ${OPS_ENABLE_HEALTHCHECKS}
OPS_ENABLE_LOG_SUMMARY: ${OPS_ENABLE_LOG_SUMMARY}
EOF
}

main() {
  print_phase_header "PHASE-10" "operations and resilience"
  collect_inputs
  validate_inputs
  save_configs_if_requested
  check_commands
  generate_files
  log_info "phase 10 operations and resilience completed successfully"
  log_info "next step: run ./scripts/phases/phase-10-verify.ksh"
}

main "$@"
