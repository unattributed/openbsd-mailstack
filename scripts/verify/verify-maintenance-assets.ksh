#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"

[ -f "${COMMON_LIB}" ] || { print -- "ERROR missing common library: ${COMMON_LIB}" >&2; exit 1; }
. "${COMMON_LIB}"

check_file() {
  _rel="$1"
  if [ -f "${PROJECT_ROOT}/${_rel}" ]; then
    print -- "PASS ${_rel}"
  else
    print -- "WARN ${_rel} missing"
  fi
}

main() {
  print_phase_header "VERIFY-MAINT" "verify maintenance assets"
  for _rel in \
    config/maintenance.conf.example \
    docs/install/17-maintenance-upgrades-regression-and-rollback.md \
    docs/operations/06-maintenance-upgrades-and-regression.md \
    scripts/lib/maintenance-regression.ksh \
    scripts/install/install-maintenance-assets.ksh \
    scripts/verify/verify-maintenance-assets.ksh \
    scripts/ops/maintenance-run.ksh \
    scripts/ops/operations-readiness-report.ksh \
    maint/openbsd-syspatch.ksh \
    maint/openbsd-pkg-upgrade.ksh \
    maint/regression-test.ksh \
    maint/rollback-on-failure.ksh \
    maint/qemu/lab-openbsd78-upgrade.ksh; do
    check_file "${_rel}"
  done
}

main "$@"
