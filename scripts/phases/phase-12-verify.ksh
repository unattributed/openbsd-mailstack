#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
PROFILE_LIB="${PROJECT_ROOT}/scripts/lib/backup-dr-phase-profiles.ksh"
. "${PROFILE_LIB}"

FAIL=0
pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=$((FAIL + 1)); }

PLAN_DIR="$(backupdr_profile_phase_dir 12)"
for _file in   "${PLAN_DIR}/phase-12-summary.txt"   "${PLAN_DIR}/integrity-workflow.txt"   "${PLAN_DIR}/restore-modes.txt"   "${PLAN_DIR}/archive-protection.txt"   "${PROJECT_ROOT}/scripts/ops/verify-backup-set.ksh"   "${PROJECT_ROOT}/scripts/ops/protect-backup-set.ksh"   "${PROJECT_ROOT}/scripts/ops/restore-mailstack.ksh"
do
  [ -f "${_file}" ] && pass "found ${_file}" || fail "missing ${_file}"
  if [ -f "${_file}" ] && ! backupdr_profile_check_no_placeholders "${_file}"; then
    fail "unresolved placeholder token found in ${_file}"
  fi
done
[ "${FAIL}" -eq 0 ]
