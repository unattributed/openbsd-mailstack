#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"
if [ -x "${REPO_ROOT}/scripts/ops/maintenance-run.ksh" ]; then
  ksh "${REPO_ROOT}/scripts/ops/maintenance-run.ksh" --report
fi
if [ -x "${REPO_ROOT}/scripts/ops/weekly-operator-review.ksh" ]; then
  ksh "${REPO_ROOT}/scripts/ops/weekly-operator-review.ksh"
fi
