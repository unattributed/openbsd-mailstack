#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
LIB="${PROJECT_ROOT}/scripts/lib/maintenance-regression.ksh"

[ -f "${LIB}" ] || { print -- "ERROR missing library: ${LIB}" >&2; exit 1; }
. "${LIB}"

main() {
  require_command ksh
  load_maintenance_settings
  print_phase_header "MAINT-PREFLIGHT" "maintenance preflight"
  require_clean_repo_if_enabled
  run_repo_guard_if_enabled
  run_design_authority_if_enabled
  if [ -x "${PROJECT_ROOT}/maint/verify-mailstack.ksh" ]; then
    log_info "running verify-mailstack baseline"
    ksh "${PROJECT_ROOT}/maint/verify-mailstack.ksh"
  fi
  log_info "maintenance preflight completed"
}

main "$@"
