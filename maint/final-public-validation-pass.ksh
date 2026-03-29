#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
REPO_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"
READINESS="${REPO_ROOT}/scripts/verify/verify-public-repo-readiness.ksh"
DESIGN="${REPO_ROOT}/maint/design-authority-check.ksh"

[ -x "${READINESS}" ] || { print -- "missing readiness verifier: ${READINESS}" >&2; exit 1; }
[ -x "${DESIGN}" ] || { print -- "missing design authority verifier: ${DESIGN}" >&2; exit 1; }

print -- "== public-only validation pass =="
ksh "${READINESS}"
print
ksh "${DESIGN}" --repo-only
