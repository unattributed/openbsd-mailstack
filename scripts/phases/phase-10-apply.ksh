#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
PROFILE_LIB="${PROJECT_ROOT}/scripts/lib/operations-phase-profiles.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing common library: ${COMMON_LIB}" >&2
  exit 1
}
[ -f "${PROFILE_LIB}" ] || {
  print -- "ERROR missing operations profile library: ${PROFILE_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"
. "${PROFILE_LIB}"

PLAN_DIR="$(operations_profile_phase_dir 10)"
DAILY_REVIEW="${PLAN_DIR}/daily-review.txt"
WEEKLY_REVIEW="${PLAN_DIR}/weekly-review.txt"
BACKUP_POSTURE="${PLAN_DIR}/backup-posture.txt"
LOG_REVIEW="${PLAN_DIR}/log-review-plan.txt"
MAINT_ENTRYPOINTS="${PLAN_DIR}/maintenance-entrypoints.txt"
OPS_SUMMARY="${PLAN_DIR}/phase-10-summary.txt"
SAVE_CONFIG="${SAVE_CONFIG:-no}"
SYSTEM_CONF="${PROJECT_ROOT}/config/system.conf"

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
  write_named_config "${SYSTEM_CONF}"     "OPENBSD_VERSION" "${OPENBSD_VERSION:-7.8}"     "MAIL_HOSTNAME" "${MAIL_HOSTNAME}"     "PRIMARY_DOMAIN" "${PRIMARY_DOMAIN:-example.com}"     "ADMIN_EMAIL" "${ADMIN_EMAIL}"     "ALERT_EMAIL" "${ALERT_EMAIL}"     "PUBLIC_IPV4" "${PUBLIC_IPV4:-203.0.113.10}"     "TIMEZONE" "${TIMEZONE:-UTC}"     "TLS_CERT_MODE" "${TLS_CERT_MODE:-single_hostname}"     "TLS_ACME_PROVIDER" "${TLS_ACME_PROVIDER:-acme-client}"     "TLS_CERT_FQDN" "${TLS_CERT_FQDN:-${MAIL_HOSTNAME}}"     "TLS_CERT_PATH_FULLCHAIN" "${TLS_CERT_PATH_FULLCHAIN:-/etc/ssl/${MAIL_HOSTNAME}.fullchain.pem}"     "TLS_CERT_PATH_KEY" "${TLS_CERT_PATH_KEY:-/etc/ssl/private/${MAIL_HOSTNAME}.key}"     "ROUNDCUBE_ENABLED" "${ROUNDCUBE_ENABLED:-yes}"     "ROUNDCUBE_WEB_HOSTNAME" "${ROUNDCUBE_WEB_HOSTNAME:-${MAIL_HOSTNAME}}"     "POSTFIXADMIN_WEB_HOSTNAME" "${POSTFIXADMIN_WEB_HOSTNAME:-${MAIL_HOSTNAME}}"     "RSPAMD_UI_HOSTNAME" "${RSPAMD_UI_HOSTNAME:-${MAIL_HOSTNAME}}"     "OPS_BACKUP_MODE" "${OPS_BACKUP_MODE}"     "OPS_RETENTION_DAYS" "${OPS_RETENTION_DAYS}"     "OPS_ENABLE_ALERTS" "${OPS_ENABLE_ALERTS}"     "OPS_ENABLE_HEALTHCHECKS" "${OPS_ENABLE_HEALTHCHECKS}"     "OPS_ENABLE_LOG_SUMMARY" "${OPS_ENABLE_LOG_SUMMARY}"
}

check_commands() {
  require_command mkdir
  require_command cat
  require_command grep
  require_command awk
}

generate_files() {
  operations_profile_write_text "${DAILY_REVIEW}" "Daily operator review for ${MAIL_HOSTNAME}
1. Run ./scripts/ops/daily-operator-review.ksh
2. Review /var/log/maillog and /var/log/messages on the host
3. Confirm alert target ${ALERT_EMAIL} still matches the intended operator workflow
4. Check whether health checks are enabled: ${OPS_ENABLE_HEALTHCHECKS}
5. Check whether log summary generation is enabled: ${OPS_ENABLE_LOG_SUMMARY}"

  operations_profile_write_text "${WEEKLY_REVIEW}" "Weekly operator review for ${MAIL_HOSTNAME}
1. Run ./scripts/ops/weekly-operator-review.ksh
2. Review backup and DR readiness with ./scripts/ops/backup-dr-readiness-report.ksh --write
3. Review maintenance readiness with ./scripts/ops/operations-readiness-report.ksh --write
4. Review whether alerts remain enabled: ${OPS_ENABLE_ALERTS}
5. Review retention target: ${OPS_RETENTION_DAYS} days"

  operations_profile_write_text "${BACKUP_POSTURE}" "Operations backup posture
mode: ${OPS_BACKUP_MODE}
retention days: ${OPS_RETENTION_DAYS}
related backup and DR plan packs: ${PROJECT_ROOT}/.work/backup-dr/
This phase does not create live backups. It prepares the operations posture and entrypoints for safe operator use."

  operations_profile_write_text "${LOG_REVIEW}" "Log review plan
mail hostname: ${MAIL_HOSTNAME}
alerts enabled: ${OPS_ENABLE_ALERTS}
log summary enabled: ${OPS_ENABLE_LOG_SUMMARY}
Suggested review targets:
- /var/log/maillog
- /var/log/messages
- /var/log/nginx/*
- /var/log/rspamd/*
- /var/log/clamav/*"

  operations_profile_write_text "${MAINT_ENTRYPOINTS}" "Maintenance and resilience entrypoints
Daily review: ./scripts/ops/daily-operator-review.ksh
Weekly review: ./scripts/ops/weekly-operator-review.ksh
Maintenance report: ./scripts/ops/maintenance-run.ksh --report
Maintenance apply: ./scripts/ops/maintenance-run.ksh --apply
Operations readiness: ./scripts/ops/operations-readiness-report.ksh --write
Post-install checks: ./scripts/verify/run-post-install-checks.ksh"

  operations_profile_write_text "${OPS_SUMMARY}" "Phase 10 operations and resilience summary
MAIL_HOSTNAME: ${MAIL_HOSTNAME}
ADMIN_EMAIL: ${ADMIN_EMAIL}
ALERT_EMAIL: ${ALERT_EMAIL}
OPS_BACKUP_MODE: ${OPS_BACKUP_MODE}
OPS_RETENTION_DAYS: ${OPS_RETENTION_DAYS}
OPS_ENABLE_ALERTS: ${OPS_ENABLE_ALERTS}
OPS_ENABLE_HEALTHCHECKS: ${OPS_ENABLE_HEALTHCHECKS}
OPS_ENABLE_LOG_SUMMARY: ${OPS_ENABLE_LOG_SUMMARY}
plan directory: ${PLAN_DIR}"
}

main() {
  print_phase_header "PHASE-10" "operations and resilience"
  collect_inputs
  validate_inputs
  save_configs_if_requested
  check_commands
  generate_files
  log_info "phase 10 operations and resilience completed successfully"
  log_info "generated live operations plan pack in ${PLAN_DIR}"
}

main "$@"
