#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
FAIL=0
pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=$((FAIL + 1)); }

for _file in   "${PROJECT_ROOT}/services/backup/phase-12-summary.txt"   "${PROJECT_ROOT}/services/backup/integrity-workflow.generated"   "${PROJECT_ROOT}/services/backup/restore-modes.generated"   "${PROJECT_ROOT}/scripts/ops/verify-backup-set.ksh"   "${PROJECT_ROOT}/scripts/ops/restore-mailstack.ksh"; do
  [ -f "${_file}" ] && pass "found ${_file}" || fail "missing ${_file}"
done
[ "${FAIL}" -eq 0 ]
