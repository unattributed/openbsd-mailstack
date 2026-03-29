#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

[ "${1:-}" = "--repo-only" ] || [ $# -eq 0 ] || { print -- "usage: design-authority-check.ksh [--repo-only]" >&2; exit 2; }

fail=0
check_absent() {
  _pattern="$1"
  _label="$2"
  if grep -RIn --exclude-dir='.git' --exclude='design-authority-check.ksh' --exclude='project-status.md' -- "${_pattern}" "${REPO_ROOT}/docs" "${REPO_ROOT}/scripts" "${REPO_ROOT}/maint" >/dev/null 2>&1; then
    print -- "FAIL: ${_label}"
    fail=1
  else
    print -- "PASS: ${_label}"
  fi
}

print -- "== design-authority-check =="
check_absent 'mail.blackbagsecurity.com' 'public tree does not contain private hostnames'
check_absent 'blackbagsecurity.io' 'public tree does not contain private operator mail domains in active tooling'
check_absent '192\\.168\\.1\\.' 'public tree does not contain private LAN addressing in active tooling'
check_absent '10\\.44\\.0\\.' 'public tree does not contain private WireGuard addressing in active tooling'
[ "${fail}" -eq 0 ]
