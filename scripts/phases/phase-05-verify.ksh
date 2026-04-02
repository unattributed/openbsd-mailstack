#!/bin/ksh
set -e
set -o pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
PHASE_PROFILE_LIB="${PROJECT_ROOT}/scripts/lib/core-phase-profiles.ksh"
[ -f "${COMMON_LIB}" ] || { print -- "ERROR missing shared library: ${COMMON_LIB}" >&2; exit 1; }
[ -f "${PHASE_PROFILE_LIB}" ] || { print -- "ERROR missing shared library: ${PHASE_PROFILE_LIB}" >&2; exit 1; }
. "${COMMON_LIB}"
. "${PHASE_PROFILE_LIB}"
main() {
  print_phase_header "PHASE-05" "dovecot auth and mailbox delivery verification"
  verify_core_phase_profile "05"
}
main "$@"
