#!/bin/ksh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
FAIL=0

pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=1; }
check_file() {
  if [ -f "$1" ]; then
    pass "$1 exists"
  else
    fail "$1 missing"
  fi
}

for _file in \
  "${PROJECT_ROOT}/docs/install/09-install-order-and-phase-sequence.md" \
  "${PROJECT_ROOT}/docs/install/10-qemu-first-validation-path.md" \
  "${PROJECT_ROOT}/docs/install/11-first-production-deployment-sequence.md" \
  "${PROJECT_ROOT}/docs/install/14-backup-and-restore-drill-sequence.md" \
  "${PROJECT_ROOT}/docs/install/16-monitoring-diagnostics-and-reporting.md" \
  "${PROJECT_ROOT}/docs/install/17-maintenance-upgrades-regression-and-rollback.md" \
  "${PROJECT_ROOT}/docs/install/20-targeted-public-hardening-validation-pass.md" \
  "${PROJECT_ROOT}/docs/install/21-security-hardening-and-runtime-secrets.md" \
  "${PROJECT_ROOT}/scripts/phases/phase-15-apply.ksh" \
  "${PROJECT_ROOT}/scripts/phases/phase-15-verify.ksh" \
  "${PROJECT_ROOT}/scripts/phases/phase-16-apply.ksh" \
  "${PROJECT_ROOT}/scripts/phases/phase-16-verify.ksh" \
  "${PROJECT_ROOT}/scripts/verify/verify-repo-semantic-integrity.ksh" \
  "${PROJECT_ROOT}/maint/doas-policy-baseline-check.ksh" \
  "${PROJECT_ROOT}/maint/doas-policy-transition.ksh" \
  "${PROJECT_ROOT}/maint/ssh-hardening-window.ksh" \
  "${PROJECT_ROOT}/maint/runtime-secret-layout.ksh" \
  "${PROJECT_ROOT}/maint/validate-public-hardening-surface.ksh"; do
  check_file "${_file}"
done

if grep -RIn 'mail.blackbagsecurity.com' "${PROJECT_ROOT}/README.md" "${PROJECT_ROOT}/docs" "${PROJECT_ROOT}/config" "${PROJECT_ROOT}/services" >/dev/null 2>&1; then
  fail "private hostname reference still present in publishable content"
else
  pass "no private hostname reference found in publishable content"
fi

if grep -RIn '^-r -- ' "${PROJECT_ROOT}/services/generated/rootfs" >/dev/null 2>&1; then
  fail "malformed generated example prefix still present"
else
  pass "generated rootfs examples are free of malformed prefixes"
fi

if "${PROJECT_ROOT}/maint/repo-secret-guard.ksh" >/dev/null 2>&1; then
  pass "repo secret guard passes"
else
  fail "repo secret guard reported a problem"
fi

if "${PROJECT_ROOT}/scripts/verify/verify-repo-semantic-integrity.ksh" >/dev/null 2>&1; then
  pass "repository semantic integrity checks pass"
else
  fail "repository semantic integrity checks reported a problem"
fi

[ "${FAIL}" -eq 0 ]
