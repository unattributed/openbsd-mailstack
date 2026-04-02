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

FAIL=0
pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=$((FAIL + 1)); }

PLAN_DIR="$(operations_profile_phase_dir 10)"
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

  for _file in     "${PLAN_DIR}/daily-review.txt"     "${PLAN_DIR}/weekly-review.txt"     "${PLAN_DIR}/backup-posture.txt"     "${PLAN_DIR}/log-review-plan.txt"     "${PLAN_DIR}/maintenance-entrypoints.txt"     "${PLAN_DIR}/phase-10-summary.txt"     "${PROJECT_ROOT}/scripts/ops/daily-operator-review.ksh"     "${PROJECT_ROOT}/scripts/ops/weekly-operator-review.ksh"     "${PROJECT_ROOT}/scripts/ops/maintenance-preflight.ksh"     "${PROJECT_ROOT}/scripts/ops/maintenance-run.ksh"     "${PROJECT_ROOT}/scripts/ops/maintenance-regression.ksh"     "${PROJECT_ROOT}/scripts/ops/maintenance-rollback-plan.ksh"     "${PROJECT_ROOT}/scripts/ops/operations-readiness-report.ksh"     "${PROJECT_ROOT}/scripts/verify/run-post-install-checks.ksh"     "${PROJECT_ROOT}/scripts/verify/verify-maintenance-assets.ksh"     "${PROJECT_ROOT}/scripts/install/install-maintenance-assets.ksh"     "${PROJECT_ROOT}/maint/openbsd-syspatch.ksh"     "${PROJECT_ROOT}/maint/openbsd-pkg-upgrade.ksh"     "${PROJECT_ROOT}/maint/regression-test.ksh"     "${PROJECT_ROOT}/maint/rollback-on-failure.ksh"
  do
    [ -f "${_file}" ] && pass "found ${_file}" || fail "missing ${_file}"
    if [ -f "${_file}" ] && ! operations_profile_check_no_placeholders "${_file}"; then
      fail "unresolved placeholder token found in ${_file}"
    fi
  done

  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL}"
  print

  [ "${FAIL}" -eq 0 ]
}

main "$@"
