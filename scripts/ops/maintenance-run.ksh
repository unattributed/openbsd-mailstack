#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
LIB="${PROJECT_ROOT}/scripts/lib/maintenance-regression.ksh"

[ -f "${LIB}" ] || { print -- "ERROR missing library: ${LIB}" >&2; exit 1; }
. "${LIB}"

MODE="report"
RUN_ID=""

usage() {
  cat <<'EOF2'
Usage:
  doas ./scripts/ops/maintenance-run.ksh [--report|--apply]

Behavior:
  --report  Run preflight, snapshot host state, and print the steps that would run.
  --apply   Run preflight, snapshot host state, apply syspatch and pkg_add helpers,
            then run regression and print rollback guidance on failure.
EOF2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --report) MODE="report"; shift ;;
    --apply) MODE="apply"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) print -- "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

main() {
  require_command ksh
  load_maintenance_settings
  RUN_ID="$(maintenance_run_id)"
  _state_root="$(ensure_maintenance_state_dir)"
  _run_dir="$(maintenance_snapshot_dir "${RUN_ID}")"
  ensure_directory "${_run_dir}"

  print_phase_header "MAINT-RUN" "maintenance upgrades regression and rollback"
  log_info "run id: ${RUN_ID}"
  log_info "state dir: ${_state_root}"

  ksh "${PROJECT_ROOT}/scripts/ops/maintenance-preflight.ksh"
  record_host_snapshot "${_run_dir}"

  if [ "${MODE}" = "report" ]; then
    log_info "report mode, no host changes applied"
    log_info "would run: maint/openbsd-syspatch.ksh --apply"
    log_info "would run: maint/openbsd-pkg-upgrade.ksh --apply"
    log_info "would run: maint/regression-test.ksh"
    write_maintenance_result "${RUN_ID}" "REPORT" "preflight and snapshot completed"
    exit 0
  fi

  if ! ksh "${PROJECT_ROOT}/maint/openbsd-syspatch.ksh" --apply; then
    write_maintenance_result "${RUN_ID}" "FAIL" "syspatch apply failed"
    [ "${MAINTENANCE_AUTO_ROLLBACK_PLAN}" = "yes" ] && ksh "${PROJECT_ROOT}/maint/rollback-on-failure.ksh" --run-id "${RUN_ID}" || true
    exit 1
  fi

  if ! ksh "${PROJECT_ROOT}/maint/openbsd-pkg-upgrade.ksh" --apply; then
    write_maintenance_result "${RUN_ID}" "FAIL" "pkg upgrade failed"
    [ "${MAINTENANCE_AUTO_ROLLBACK_PLAN}" = "yes" ] && ksh "${PROJECT_ROOT}/maint/rollback-on-failure.ksh" --run-id "${RUN_ID}" || true
    exit 1
  fi

  if [ "${MAINTENANCE_ENABLE_REGRESSION}" = "yes" ]; then
    if ! ksh "${PROJECT_ROOT}/maint/regression-test.ksh"; then
      write_maintenance_result "${RUN_ID}" "FAIL" "regression checks failed"
      [ "${MAINTENANCE_AUTO_ROLLBACK_PLAN}" = "yes" ] && ksh "${PROJECT_ROOT}/maint/rollback-on-failure.ksh" --run-id "${RUN_ID}" || true
      exit 1
    fi
  fi

  write_maintenance_result "${RUN_ID}" "PASS" "maintenance apply completed successfully"
  log_info "maintenance apply completed successfully"
}

main "$@"
