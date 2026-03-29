#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
MONITOR_LIB="${PROJECT_ROOT}/scripts/lib/monitoring-diagnostics.ksh"
. "${COMMON_LIB}"
. "${MONITOR_LIB}"

monitoring_load_config

if ! command_exists rcctl; then
  print -- "rcctl unavailable" >&2
  exit 1
fi

for _svc in ${MONITORING_RCCTL_SERVICES}; do
  print -- "${_svc} $(monitoring_rcctl_status "${_svc}")"
done
