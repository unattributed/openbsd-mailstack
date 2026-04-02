#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
PROFILE_LIB="${PROJECT_ROOT}/scripts/lib/backup-dr-phase-profiles.ksh"
. "${COMMON_LIB}"
. "${PROFILE_LIB}"

FAIL=0
pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=$((FAIL + 1)); }

PLAN_DIR="$(backupdr_profile_phase_dir 11)"
for _file in   "${PLAN_DIR}/phase-11-summary.txt"   "${PLAN_DIR}/backup-scope.txt"   "${PLAN_DIR}/restore-workflow.txt"   "${PLAN_DIR}/dr-site-provisioning.txt"   "${PLAN_DIR}/backup-schedule.txt"   "${PLAN_DIR}/dr-host-bootstrap.txt"   "${PROJECT_ROOT}/scripts/install/install-backup-dr-assets.ksh"   "${PROJECT_ROOT}/scripts/install/install-dr-site-assets.ksh"   "${PROJECT_ROOT}/scripts/install/install-backup-schedule-assets.ksh"   "${PROJECT_ROOT}/scripts/install/provision-dr-site-host.ksh"   "${PROJECT_ROOT}/scripts/ops/backup-config.ksh"   "${PROJECT_ROOT}/scripts/ops/backup-mariadb.ksh"   "${PROJECT_ROOT}/scripts/ops/backup-mailstack.ksh"   "${PROJECT_ROOT}/scripts/ops/backup-all.ksh"   "${PROJECT_ROOT}/scripts/ops/restore-mailstack.ksh"   "${PROJECT_ROOT}/scripts/ops/backup-dr-readiness-report.ksh"
do
  [ -f "${_file}" ] && pass "found ${_file}" || fail "missing ${_file}"
  if [ -f "${_file}" ] && ! backupdr_profile_check_no_placeholders "${_file}"; then
    fail "unresolved placeholder token found in ${_file}"
  fi
done
[ "${FAIL}" -eq 0 ]
