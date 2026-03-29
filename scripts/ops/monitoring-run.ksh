#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
MONITOR_LIB="${PROJECT_ROOT}/scripts/lib/monitoring-diagnostics.ksh"
COLLECT_SCRIPT="${PROJECT_ROOT}/scripts/ops/monitoring-collect.ksh"
SUMMARY_SCRIPT="${PROJECT_ROOT}/scripts/ops/monitoring-log-summary.ksh"
RENDER_SCRIPT="${PROJECT_ROOT}/scripts/ops/monitoring-render.ksh"
VERIFY_SCRIPT="${PROJECT_ROOT}/scripts/verify/verify-monitoring-assets.ksh"
. "${COMMON_LIB}"
. "${MONITOR_LIB}"

monitoring_load_config

[ -x "${COLLECT_SCRIPT}" ] || die "missing collector script"
[ -x "${SUMMARY_SCRIPT}" ] || die "missing log summary script"
[ -x "${RENDER_SCRIPT}" ] || die "missing render script"
[ -x "${VERIFY_SCRIPT}" ] || die "missing verify script"

ksh "${COLLECT_SCRIPT}"
ksh "${SUMMARY_SCRIPT}" --out "${MONITORING_DATA_ROOT}/log-summary.txt"
if [ "${MONITORING_ENABLE_SITE}" = "yes" ]; then
  ksh "${RENDER_SCRIPT}"
fi
ksh "${VERIFY_SCRIPT}"
print -- "monitoring run completed"
