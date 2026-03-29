#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
print_phase_header "PHASE-17" "advanced optional integrations and gap closures verification"
ksh "${PROJECT_ROOT}/scripts/verify/verify-advanced-gap-assets.ksh"
