#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

print -- "== drift-check =="
if command -v git >/dev/null 2>&1 && git -C "${REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "${REPO_ROOT}" diff --quiet --ignore-submodules HEAD --; then
    print -- "PASS: git working tree clean"
  else
    print -- "WARN: git working tree has local changes"
    git -C "${REPO_ROOT}" status --short
  fi
fi

for _f in config/secrets.conf config/maintenance.conf; do
  if [ -f "${REPO_ROOT}/${_f}" ]; then
    print -- "INFO: local operator input present: ${_f}"
  fi
done
