#!/bin/ksh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
OUT_DIR="${PROJECT_ROOT}/services/generated/rootfs/etc/examples/openbsd-mailstack"
FAIL=0

pass() { print -- "PASS $*"; }
warn() { print -- "WARN $*"; }
fail() { print -- "FAIL $*"; FAIL=1; }

for _f in   "${PROJECT_ROOT}/maint/doas-policy-baseline-check.ksh"   "${PROJECT_ROOT}/maint/doas-policy-transition.ksh"   "${PROJECT_ROOT}/maint/ssh-hardening-window.ksh"   "${PROJECT_ROOT}/maint/sshd-watchdog.ksh"   "${PROJECT_ROOT}/services/auth/etc/doas/doas.conf.baseline.template"   "${PROJECT_ROOT}/services/auth/etc/doas/doas.conf.command-scoped.template"   "${PROJECT_ROOT}/services/auth/etc/ssh/sshd_config.phase15.template"   "${OUT_DIR}/doas.conf.baseline"   "${OUT_DIR}/doas.conf.command-scoped"   "${OUT_DIR}/sshd_config.phase15"   "${OUT_DIR}/authentication-policy.txt"   "${OUT_DIR}/password-policy.txt"   "${OUT_DIR}/second-factor-roadmap.txt"   "${OUT_DIR}/phase-15-summary.txt"; do
  if [ -f "${_f}" ]; then
    pass "${_f} exists"
  else
    fail "${_f} missing"
  fi
done

if grep -RIn 'mail.blackbagsecurity.com' "${PROJECT_ROOT}/services/auth" >/dev/null 2>&1; then
  fail "services/auth still contains a private hostname reference"
else
  pass "services/auth is free of private hostname references"
fi

[ "${FAIL}" -eq 0 ]
