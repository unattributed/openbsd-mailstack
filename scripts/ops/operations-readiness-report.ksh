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

MODE="print"
if [ "${1:-}" = "--write" ]; then
  MODE="write"
fi

load_project_config
prompt_value "MAIL_HOSTNAME" "Enter the public mail hostname" "${MAIL_HOSTNAME:-mail.example.com}"
prompt_value "ADMIN_EMAIL" "Enter the administrator email address" "${ADMIN_EMAIL:-ops@example.com}"
prompt_value "ALERT_EMAIL" "Enter the operational alert email address" "${ALERT_EMAIL:-${ADMIN_EMAIL}}"
prompt_value "OPS_BACKUP_MODE" "Enter the backup mode" "${OPS_BACKUP_MODE:-local}"
prompt_value "OPS_RETENTION_DAYS" "Enter the retention period in days" "${OPS_RETENTION_DAYS:-14}"
prompt_value "OPS_ENABLE_ALERTS" "Enable alerts, yes or no" "${OPS_ENABLE_ALERTS:-yes}"
prompt_value "OPS_ENABLE_HEALTHCHECKS" "Enable health checks, yes or no" "${OPS_ENABLE_HEALTHCHECKS:-yes}"
prompt_value "OPS_ENABLE_LOG_SUMMARY" "Enable log summary generation, yes or no" "${OPS_ENABLE_LOG_SUMMARY:-yes}"

validate_hostname "${MAIL_HOSTNAME}" || die "invalid MAIL_HOSTNAME: ${MAIL_HOSTNAME}"
validate_email "${ADMIN_EMAIL}" || die "invalid ADMIN_EMAIL: ${ADMIN_EMAIL}"
validate_email "${ALERT_EMAIL}" || die "invalid ALERT_EMAIL: ${ALERT_EMAIL}"
validate_mode_word "${OPS_BACKUP_MODE}" || die "invalid OPS_BACKUP_MODE: ${OPS_BACKUP_MODE}"
validate_numeric "${OPS_RETENTION_DAYS}" || die "invalid OPS_RETENTION_DAYS: ${OPS_RETENTION_DAYS}"
validate_yes_no "${OPS_ENABLE_ALERTS}" || die "OPS_ENABLE_ALERTS must be yes or no"
validate_yes_no "${OPS_ENABLE_HEALTHCHECKS}" || die "OPS_ENABLE_HEALTHCHECKS must be yes or no"
validate_yes_no "${OPS_ENABLE_LOG_SUMMARY}" || die "OPS_ENABLE_LOG_SUMMARY must be yes or no"

REPORT_PATH="$(operations_readiness_dir)/operations-readiness.txt"
REPORT_CONTENT="Operations readiness report
mail hostname: ${MAIL_HOSTNAME}
admin email: ${ADMIN_EMAIL}
alert email: ${ALERT_EMAIL}
backup mode: ${OPS_BACKUP_MODE}
retention days: ${OPS_RETENTION_DAYS}
alerts enabled: ${OPS_ENABLE_ALERTS}
health checks enabled: ${OPS_ENABLE_HEALTHCHECKS}
log summary enabled: ${OPS_ENABLE_LOG_SUMMARY}
phase 10 plan directory: $(operations_profile_phase_dir 10)
daily review entrypoint: ${PROJECT_ROOT}/scripts/ops/daily-operator-review.ksh
weekly review entrypoint: ${PROJECT_ROOT}/scripts/ops/weekly-operator-review.ksh
maintenance run entrypoint: ${PROJECT_ROOT}/scripts/ops/maintenance-run.ksh
post-install checks: ${PROJECT_ROOT}/scripts/verify/run-post-install-checks.ksh"

if [ "${MODE}" = "write" ]; then
  operations_profile_write_text "${REPORT_PATH}" "${REPORT_CONTENT}"
  print -- "${REPORT_PATH}"
else
  print -- "${REPORT_CONTENT}"
fi
