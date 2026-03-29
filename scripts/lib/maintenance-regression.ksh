#!/bin/ksh
set -u

SELF_PATH="${.sh.file}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${SELF_PATH}")" && pwd -P)"
COMMON_LIB="${SCRIPT_DIR}/common.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing common library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

: "${MAINTENANCE_STATE_DIR:=/var/db/openbsd-mailstack}"
: "${ALERT_EMAIL:=ops@example.net}"
: "${ALERT_FROM:=root@mail.example.net}"
: "${REGRESSION_PROBE_TO:=}"
: "${PKG_ADD_TIMEOUT_SECS:=1800}"
: "${ALLOW_PKG_TIMEOUT_CONTINUE:=0}"
: "${SYSPATCH_FALLBACK_URL:=https://cdn.openbsd.org/pub/OpenBSD}"
: "${MAINTENANCE_REQUIRE_CLEAN_GIT:=yes}"
: "${MAINTENANCE_ENABLE_SECRET_GUARD:=yes}"
: "${MAINTENANCE_ENABLE_DESIGN_AUTHORITY:=yes}"
: "${MAINTENANCE_ENABLE_REGRESSION:=yes}"
: "${MAINTENANCE_ENABLE_PROBE:=no}"
: "${MAINTENANCE_AUTO_ROLLBACK_PLAN:=yes}"
: "${MAINTENANCE_CRON_DAY:=0}"
: "${MAINTENANCE_CRON_HOUR:=4}"
: "${MAINTENANCE_CRON_MINUTE:=15}"

load_maintenance_settings() {
  load_project_config
  : "${MAINTENANCE_STATE_DIR:=/var/db/openbsd-mailstack}"
}

maintenance_state_dir() {
  print -- "${MAINTENANCE_STATE_DIR}"
}

ensure_maintenance_state_dir() {
  _dir="$(maintenance_state_dir)"
  ensure_directory "${_dir}"
  print -- "${_dir}"
}

maintenance_run_id() {
  date -u +"%Y%m%dT%H%M%SZ"
}

maintenance_snapshot_dir() {
  _run_id="$1"
  print -- "$(maintenance_state_dir)/runs/${_run_id}"
}

require_clean_repo_if_enabled() {
  [ "${MAINTENANCE_REQUIRE_CLEAN_GIT}" = "yes" ] || return 0
  command_exists git || return 0
  git -C "${PROJECT_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git -C "${PROJECT_ROOT}" diff --quiet --ignore-submodules HEAD -- || \
    die "git working tree is not clean, commit or stash before maintenance"
}

run_repo_guard_if_enabled() {
  [ "${MAINTENANCE_ENABLE_SECRET_GUARD}" = "yes" ] || return 0
  _guard="${PROJECT_ROOT}/maint/repo-secret-guard.ksh"
  [ -x "${_guard}" ] || return 0
  ksh "${_guard}"
}

run_design_authority_if_enabled() {
  [ "${MAINTENANCE_ENABLE_DESIGN_AUTHORITY}" = "yes" ] || return 0
  _guard="${PROJECT_ROOT}/maint/design-authority-check.ksh"
  [ -x "${_guard}" ] || return 0
  ksh "${_guard}" --repo-only
}

record_host_snapshot() {
  _dest_dir="$1"
  ensure_directory "${_dest_dir}"
  {
    print -- "timestamp=$(timestamp)"
    print -- "hostname=$(hostname 2>/dev/null || print -- unknown)"
    print -- "osrelease=$(uname -r 2>/dev/null || print -- unknown)"
  } > "${_dest_dir}/metadata.env"

  if command_exists syspatch; then
    syspatch -l > "${_dest_dir}/syspatch-installed.txt" 2>&1 || true
    syspatch -c > "${_dest_dir}/syspatch-pending.txt" 2>&1 || true
  fi
  if command_exists pkg_info; then
    pkg_info -q > "${_dest_dir}/pkg-info.txt" 2>&1 || true
  fi
  if command_exists rcctl; then
    rcctl ls all > "${_dest_dir}/rcctl-all.txt" 2>&1 || true
    rcctl ls on > "${_dest_dir}/rcctl-on.txt" 2>&1 || true
  fi
  if command_exists df; then
    df -h > "${_dest_dir}/df-h.txt" 2>&1 || true
  fi
}

maintenance_result_file() {
  _run_id="$1"
  print -- "$(maintenance_snapshot_dir "${_run_id}")/result.env"
}

write_maintenance_result() {
  _run_id="$1"
  _result="$2"
  _note="${3:-}"
  _out="$(maintenance_result_file "${_run_id}")"
  ensure_directory "$(dirname -- "${_out}")"
  {
    print -- "RESULT=${_result}"
    print -- "UPDATED_AT=$(timestamp)"
    print -- "NOTE=${_note}"
  } > "${_out}"
}
