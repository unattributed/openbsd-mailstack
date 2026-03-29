#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
POST_INSTALL_CHECKS="${PROJECT_ROOT}/scripts/verify/run-post-install-checks.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing shared library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

main() {
  print_phase_header "DAILY-OPS" "daily operator review"
  [ -f "${POST_INSTALL_CHECKS}" ] || die "missing post-install checker: ${POST_INSTALL_CHECKS}"

  if [ "$(uname -s 2>/dev/null || true)" = "OpenBSD" ]; then
    log_info "running host-focused daily checks"
    ksh "${POST_INSTALL_CHECKS}" --host-only
  else
    log_warn "not running on OpenBSD, falling back to repo-only checks"
    ksh "${POST_INSTALL_CHECKS}" --repo-only
  fi
}

main "$@"
