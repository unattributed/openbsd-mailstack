#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"

[ -f "${COMMON_LIB}" ] || { print -- "ERROR missing common library: ${COMMON_LIB}" >&2; exit 1; }
. "${COMMON_LIB}"

: "${MAINT_SBINDIR:=/usr/local/sbin}"
: "${MAINT_CRON_PATH:=/var/cron/tabs/root}"
: "${INSTALL_MAINTENANCE_CRON:=no}"

main() {
  require_command install
  load_project_config
  print_phase_header "INSTALL-MAINT" "install maintenance and regression assets"

  ensure_directory "${MAINT_SBINDIR}"
  for _src in \
    maint/openbsd-syspatch.ksh \
    maint/openbsd-pkg-upgrade.ksh \
    maint/regression-test.ksh \
    maint/rollback-on-failure.ksh \
    maint/drift-check.ksh \
    maint/git-safe-sync.ksh \
    maint/repo-secret-guard.ksh \
    maint/design-authority-check.ksh \
    maint/phase-todo-audit.ksh \
    maint/install-weekly-ops-cron.ksh \
    maint/weekly-maintenance-cron.ksh \
    maint/verify-mailstack.ksh \
    scripts/ops/operations-readiness-report.ksh; do
    _path="${PROJECT_ROOT}/${_src}"
    [ -f "${_path}" ] || continue
    install -m 0755 "${_path}" "${MAINT_SBINDIR}/$(basename -- "${_src}")"
    log_info "installed $(basename -- "${_src}") into ${MAINT_SBINDIR}"
  done

  if [ "${INSTALL_MAINTENANCE_CRON}" = "yes" ]; then
    ksh "${PROJECT_ROOT}/maint/install-weekly-ops-cron.ksh" --cron-path "${MAINT_CRON_PATH}"
  else
    log_info "cron installation skipped, set INSTALL_MAINTENANCE_CRON=yes to enable"
  fi
}

main "$@"
