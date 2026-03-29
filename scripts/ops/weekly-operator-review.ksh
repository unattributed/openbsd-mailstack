#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
POST_INSTALL_CHECKS="${PROJECT_ROOT}/scripts/verify/run-post-install-checks.ksh"
PHASE_RUNNER="${PROJECT_ROOT}/scripts/install/run-phase-sequence.ksh"
CORE_VERIFY="${PROJECT_ROOT}/scripts/verify/verify-core-runtime-assets.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing shared library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

PHASE_END="${PHASE_END:-10}"

main() {
  print_phase_header "WEEKLY-OPS" "weekly operator review"

  [ -f "${POST_INSTALL_CHECKS}" ] || die "missing post-install checker: ${POST_INSTALL_CHECKS}"
  [ -f "${PHASE_RUNNER}" ] || die "missing phase runner: ${PHASE_RUNNER}"
  [ -f "${CORE_VERIFY}" ] || die "missing core runtime verifier: ${CORE_VERIFY}"

  log_info "running full post-install checks"
  ksh "${POST_INSTALL_CHECKS}"

  log_info "running core runtime asset verification"
  ksh "${CORE_VERIFY}"

  log_info "running phase verify suite through phase ${PHASE_END}"
  ksh "${PHASE_RUNNER}" --phase-start 0 --phase-end "${PHASE_END}" --verify-only
}

main "$@"
