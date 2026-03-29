#!/bin/ksh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"
exec ksh "${PROJECT_ROOT}/scripts/ops/suricata-dump.ksh" "$@"
