#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${COMMON_LIB}"

FAIL=0
pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=$((FAIL + 1)); }

for _file in   "${PROJECT_ROOT}/config/backup.conf.example"   "${PROJECT_ROOT}/config/dr-site.conf.example"   "${PROJECT_ROOT}/scripts/lib/backup-dr.ksh"   "${PROJECT_ROOT}/scripts/install/install-backup-dr-assets.ksh"   "${PROJECT_ROOT}/scripts/install/install-dr-site-assets.ksh"   "${PROJECT_ROOT}/scripts/ops/backup-config.ksh"   "${PROJECT_ROOT}/scripts/ops/backup-mariadb.ksh"   "${PROJECT_ROOT}/scripts/ops/backup-mailstack.ksh"   "${PROJECT_ROOT}/scripts/ops/restore-mailstack.ksh"   "${PROJECT_ROOT}/scripts/ops/run-restore-drill.ksh"   "${PROJECT_ROOT}/scripts/ops/replicate-backup-offhost.ksh"; do
  [ -f "${_file}" ] && pass "found ${_file}" || fail "missing ${_file}"
done

[ "${FAIL}" -eq 0 ]
