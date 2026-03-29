#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
LIB="${PROJECT_ROOT}/scripts/lib/maintenance-regression.ksh"

[ -f "${LIB}" ] || { print -- "ERROR missing library: ${LIB}" >&2; exit 1; }
. "${LIB}"

main() {
  load_maintenance_settings
  print_phase_header "MAINT-REGRESSION" "maintenance regression checks"
  if [ -x "${PROJECT_ROOT}/maint/regression-test.ksh" ]; then
    ksh "${PROJECT_ROOT}/maint/regression-test.ksh"
  elif [ -x "${PROJECT_ROOT}/maint/verify-mailstack.ksh" ]; then
    ksh "${PROJECT_ROOT}/maint/verify-mailstack.ksh"
  else
    die "no regression helper found in maint/"
  fi
}

main "$@"
