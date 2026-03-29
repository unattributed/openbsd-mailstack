#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODE="--report"

[ "${1:-}" = "--check" ] && MODE="--check"

TMP="$(mktemp /tmp/openbsd-mailstack-todo.XXXXXX)"
trap 'rm -f "${TMP}"' EXIT HUP INT TERM
find "${REPO_ROOT}/docs" "${REPO_ROOT}/scripts" -type f \( -name '*.md' -o -name '*.ksh' \) -print0 | \
  xargs -0 grep -n 'TODO' > "${TMP}" 2>/dev/null || true

if [ -s "${TMP}" ]; then
  cat "${TMP}"
  [ "${MODE}" = "--check" ] && exit 1
else
  print -- "No TODO markers found"
fi
