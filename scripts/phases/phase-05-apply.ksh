#!/bin/ksh
set -e
set -o pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
[ -f "${COMMON_LIB}" ] || { print -- "ERROR missing shared library: ${COMMON_LIB}" >&2; exit 1; }
. "${COMMON_LIB}"
main() {
  print_phase_header "PHASE-05" "dovecot auth and mailbox delivery"
  "${PROJECT_ROOT}/scripts/install/render-core-runtime-configs.ksh"
  log_info "phase 05 dovecot auth and mailbox delivery completed successfully"
  log_info "next step: run ./scripts/phases/phase-05-verify.ksh"
}
main "$@"
