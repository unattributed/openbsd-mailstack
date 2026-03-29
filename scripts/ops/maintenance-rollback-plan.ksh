#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
ROLLBACK="${PROJECT_ROOT}/maint/rollback-on-failure.ksh"

[ -x "${ROLLBACK}" ] || { print -- "ERROR missing rollback helper: ${ROLLBACK}" >&2; exit 1; }
exec ksh "${ROLLBACK}" "$@"
