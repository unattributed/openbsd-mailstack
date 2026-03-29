#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
FAIL=0
pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=$((FAIL + 1)); }

for _file in   "${PROJECT_ROOT}/services/backup/phase-13-summary.txt"   "${PROJECT_ROOT}/services/backup/offhost-replication.generated"   "${PROJECT_ROOT}/services/backup/restore-drill.generated"   "${PROJECT_ROOT}/services/monitoring/post-restore-validation.generated"   "${PROJECT_ROOT}/maint/qemu/lab-dr-restore-runner.ksh"   "${PROJECT_ROOT}/scripts/ops/replicate-backup-offhost.ksh"; do
  [ -f "${_file}" ] && pass "found ${_file}" || fail "missing ${_file}"
done
[ "${FAIL}" -eq 0 ]
