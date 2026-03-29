#!/bin/ksh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
OUT_DIR="${PROJECT_ROOT}/services/generated/rootfs/etc/examples/openbsd-mailstack"
FAIL=0

pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=1; }

for _f in   "${PROJECT_ROOT}/maint/runtime-secret-layout.ksh"   "${PROJECT_ROOT}/maint/repo-secret-guard.ksh"   "${PROJECT_ROOT}/services/secrets/etc/examples/postfixadmin-db.env.template"   "${PROJECT_ROOT}/services/secrets/etc/examples/sogo-db.env.template"   "${PROJECT_ROOT}/services/secrets/etc/postfixadmin/secrets.php.template"   "${PROJECT_ROOT}/services/secrets/etc/roundcube/secrets.inc.php.template"   "${PROJECT_ROOT}/services/generated/rootfs/etc/postfixadmin/secrets.php.example"   "${PROJECT_ROOT}/services/generated/rootfs/etc/roundcube/secrets.inc.php.example"   "${OUT_DIR}/postfixadmin-db.env"   "${OUT_DIR}/sogo-db.env"   "${OUT_DIR}/runtime-secret-paths.txt"   "${OUT_DIR}/runtime-secret-permissions.txt"   "${OUT_DIR}/rotation-checklist.txt"   "${OUT_DIR}/phase-16-summary.txt"; do
  if [ -f "${_f}" ]; then
    pass "${_f} exists"
  else
    fail "${_f} missing"
  fi
done

if ${PROJECT_ROOT}/maint/repo-secret-guard.ksh >/dev/null 2>&1; then
  pass "repo-secret-guard.ksh passes on the tracked repo state"
else
  fail "repo-secret-guard.ksh reported a tracked secret hygiene issue"
fi

[ "${FAIL}" -eq 0 ]
