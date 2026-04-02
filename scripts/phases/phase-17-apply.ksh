#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
print_phase_header "PHASE-17" "advanced optional integrations and gap closures"
ksh "${PROJECT_ROOT}/scripts/install/render-advanced-gap-configs.ksh"
print -- "Phase 17 completed, with live optional renders now staged under ${OPENBSD_MAILSTACK_ADVANCED_RENDER_ROOT:-${PROJECT_ROOT}/.work/advanced/rootfs}"
