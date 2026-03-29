#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"
VERIFY_POST_INSTALL="${PROJECT_ROOT}/scripts/verify/run-post-install-checks.ksh"
VERIFY_MONITORING="${PROJECT_ROOT}/scripts/verify/verify-monitoring-assets.ksh"
MONITORING_RUN="${PROJECT_ROOT}/scripts/ops/monitoring-run.ksh"

[ -x "${MONITORING_RUN}" ] || { print -- "missing ${MONITORING_RUN}" >&2; exit 1; }
[ -x "${VERIFY_MONITORING}" ] || { print -- "missing ${VERIFY_MONITORING}" >&2; exit 1; }

ksh "${MONITORING_RUN}"
ksh "${VERIFY_MONITORING}"
if [ -x "${VERIFY_POST_INSTALL}" ]; then
  ksh "${VERIFY_POST_INSTALL}"
fi
