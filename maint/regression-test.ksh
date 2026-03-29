#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ALERT_TO="${ALERT_EMAIL:-${ALERT_TO:-}}"
REGRESSION_PROBE_TO="${REGRESSION_PROBE_TO:-}"

pass() { print -- "PASS: $*"; }
warn() { print -- "WARN: $*"; }
fail() { print -- "FAIL: $*"; exit 1; }

run_verify() {
  if [ -x "${SCRIPT_DIR}/verify-mailstack.ksh" ]; then
    ksh "${SCRIPT_DIR}/verify-mailstack.ksh" || return 1
  else
    warn "verify-mailstack.ksh not found, skipping service verification"
  fi
}

probe_mail_path() {
  [ -n "${REGRESSION_PROBE_TO}" ] || return 0
  command -v sendmail >/dev/null 2>&1 || return 0
  {
    print -- "To: ${REGRESSION_PROBE_TO}"
    [ -n "${ALERT_TO}" ] && print -- "From: ${ALERT_TO}"
    print -- "Subject: openbsd-mailstack maintenance probe $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    print
    print -- "This is a public-safe maintenance regression probe from openbsd-mailstack."
  } | sendmail -t || return 1
}

run_verify || fail "service verification failed"
probe_mail_path || fail "mail probe failed"
pass "maintenance regression baseline passed"
