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

OPS_DIR="${PROJECT_ROOT}/services/ops"
BACKUP_DIR="${PROJECT_ROOT}/services/backup"
MON_DIR="${PROJECT_ROOT}/services/monitoring"

HEALTHCHECK="${OPS_DIR}/healthcheck.example.generated"
RCCTL_REVIEW="${OPS_DIR}/rcctl-review.example.generated"
BACKUP_PLAN="${BACKUP_DIR}/backup-plan.example.generated"
LOG_SUMMARY="${MON_DIR}/log-summary.example.generated"
OPS_SUMMARY="${OPS_DIR}/operations-summary.txt"

FAIL_COUNT=0
WARN_COUNT=0

pass() { print -- "[$(timestamp)] PASS  $*"; }
warn() { print -- "[$(timestamp)] WARN  $*"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { print -- "[$(timestamp)] FAIL  $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

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

main() {
  print_phase_header "PHASE-10" "operations and resilience verification"
  collect_inputs

  validate_hostname "${MAIL_HOSTNAME}" && pass "MAIL_HOSTNAME is valid: ${MAIL_HOSTNAME}" || fail "MAIL_HOSTNAME is invalid"
  validate_email "${ADMIN_EMAIL}" && pass "ADMIN_EMAIL is valid: ${ADMIN_EMAIL}" || fail "ADMIN_EMAIL is invalid"
  validate_email "${ALERT_EMAIL}" && pass "ALERT_EMAIL is valid: ${ALERT_EMAIL}" || fail "ALERT_EMAIL is invalid"
  validate_mode_word "${OPS_BACKUP_MODE}" && pass "OPS_BACKUP_MODE is valid: ${OPS_BACKUP_MODE}" || fail "OPS_BACKUP_MODE is invalid"
  validate_numeric "${OPS_RETENTION_DAYS}" && pass "OPS_RETENTION_DAYS is valid: ${OPS_RETENTION_DAYS}" || fail "OPS_RETENTION_DAYS is invalid"
  validate_yes_no "${OPS_ENABLE_ALERTS}" && pass "OPS_ENABLE_ALERTS is valid: ${OPS_ENABLE_ALERTS}" || fail "OPS_ENABLE_ALERTS is invalid"
  validate_yes_no "${OPS_ENABLE_HEALTHCHECKS}" && pass "OPS_ENABLE_HEALTHCHECKS is valid: ${OPS_ENABLE_HEALTHCHECKS}" || fail "OPS_ENABLE_HEALTHCHECKS is invalid"
  validate_yes_no "${OPS_ENABLE_LOG_SUMMARY}" && pass "OPS_ENABLE_LOG_SUMMARY is valid: ${OPS_ENABLE_LOG_SUMMARY}" || fail "OPS_ENABLE_LOG_SUMMARY is invalid"

  for cmd in rcctl tar gzip grep awk mkdir cat; do
    command_exists "${cmd}" && pass "required command present: ${cmd}" || fail "required command missing: ${cmd}"
  done

  for file in "${HEALTHCHECK}" "${RCCTL_REVIEW}" "${BACKUP_PLAN}" "${LOG_SUMMARY}" "${OPS_SUMMARY}"; do
    [ -f "${file}" ] && pass "generated file exists: ${file}" || warn "generated file is missing: ${file}"
  done

  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  print

  [ "${FAIL_COUNT}" -eq 0 ]
}

main "$@"
