#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P 2>/dev/null || pwd -P)"
load_monitoring_inputs() {
  for _dir in     "${PROJECT_ROOT}/config"     "${PROJECT_ROOT}/config/local"     "/etc/openbsd-mailstack"     "/root/.config/openbsd-mailstack"     "${HOME:-/root}/.config/openbsd-mailstack"
  do
    [ -d "${_dir}" ] || continue
    for _f in "${_dir}"/*.conf; do
      [ -f "${_f}" ] || continue
      . "${_f}"
    done
  done
}
load_monitoring_inputs
MONITORING_PRIMARY_REPORT_EMAIL="${MONITORING_PRIMARY_REPORT_EMAIL:-$(printf '%s\n' "${MONITORING_REPORT_EMAIL:-ops@example.com}" | awk '{print $1}')}"
PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"
umask 022

PROG="${0##*/}"
COLLECTOR="${COLLECTOR:-/usr/local/libexec/openbsd-mailstack/monitoring/monitoring-collect.ksh}"
RENDERER="${RENDERER:-/usr/local/libexec/openbsd-mailstack/monitoring/monitoring-render.ksh}"
VERIFIER="${VERIFIER:-/usr/local/libexec/openbsd-mailstack/monitoring/verify-monitoring-assets.ksh}"
PHASE14_FAST_PATH_CMD="${PHASE14_FAST_PATH_CMD:-${MONITORING_PHASE14_FAST_PATH_CMD:-}}"
PHASE14_FAST_PATH_ENABLE="${PHASE14_FAST_PATH_ENABLE:-1}"
PHASE14_FAST_PATH_TIMEOUT_SECS="${PHASE14_FAST_PATH_TIMEOUT_SECS:-240}"
RUN_VERIFY="${RUN_VERIFY:-1}"
COLLECT_TIMEOUT_SECS="${COLLECT_TIMEOUT_SECS:-300}"
RENDER_TIMEOUT_SECS="${RENDER_TIMEOUT_SECS:-300}"
VERIFY_TIMEOUT_SECS="${VERIFY_TIMEOUT_SECS:-180}"
TIMEOUT_KILL_GRACE_SECS="${TIMEOUT_KILL_GRACE_SECS:-5}"
LOCK_DIR="${LOCK_DIR:-/var/run/openbsd-mailstack-monitoring.lock}"
LOCK_META="${LOCK_DIR}/meta"
LOCK_STALE_SECS="${LOCK_STALE_SECS:-960}"
INTERNAL_NOLOCK="${1:-}"

# Summary:
#   ts helper.
ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

# Summary:
#   log helper.
log() { print -- "[${PROG}] $(ts) $*"; }

# Summary:
#   die helper.
die() {
  log "error: $*"
  exit 1
}

# Summary:
#   need_exec helper.
need_exec() {
  [ -x "$1" ] || die "required executable missing: $1"
}

# Summary:
#   num_or_default helper.
num_or_default() {
  _v="$1"
  _d="$2"
  case "${_v}" in
    ''|*[!0-9]*) printf '%s\n' "${_d}" ;;
    *) printf '%s\n' "${_v}" ;;
  esac
}

# Summary:
#   ps_cmdline helper.
ps_cmdline() {
  _pid="$1"
  _cmd="$(ps -p "${_pid}" -o command= 2>/dev/null | head -n 1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -n "${_cmd}" ] || _cmd="$(ps -p "${_pid}" -o args= 2>/dev/null | head -n 1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  printf '%s\n' "${_cmd}"
}

# Summary:
#   cleanup_lock helper.
cleanup_lock() {
  rm -rf "${LOCK_DIR}" 2>/dev/null || true
}

# Summary:
#   lock_is_active helper.
lock_is_active() {
  [ -d "${LOCK_DIR}" ] || return 1
  [ -r "${LOCK_META}" ] || return 1

  _pid="$(awk -F= '$1=="pid"{print $2; exit}' "${LOCK_META}" 2>/dev/null || true)"
  _started="$(awk -F= '$1=="started_epoch"{print $2; exit}' "${LOCK_META}" 2>/dev/null || true)"
  _pid="$(num_or_default "${_pid}" 0)"
  _started="$(num_or_default "${_started}" 0)"

  [ "${_pid}" -gt 1 ] || return 1
  [ "${_started}" -gt 0 ] || return 1

  _now="$(date +%s)"
  _age="$(( _now - _started ))"
  if [ "${_age}" -lt 0 ] || [ "${_age}" -gt "${LOCK_STALE_SECS}" ]; then
    return 1
  fi

  if ! kill -0 "${_pid}" 2>/dev/null; then
    return 1
  fi

  _cmd="$(ps_cmdline "${_pid}")"
  case "${_cmd}" in
    *monitoring-run.ksh*) return 0 ;;
    *) return 1 ;;
  esac
}

# Summary:
#   acquire_lock helper.
acquire_lock() {
  mkdir -p "$(dirname "${LOCK_DIR}")" 2>/dev/null || true

  if mkdir "${LOCK_DIR}" 2>/dev/null; then
    :
  elif lock_is_active; then
    _pid="$(awk -F= '$1=="pid"{print $2; exit}' "${LOCK_META}" 2>/dev/null || true)"
    _started="$(awk -F= '$1=="started_epoch"{print $2; exit}' "${LOCK_META}" 2>/dev/null || true)"
    _started="$(num_or_default "${_started}" 0)"
    _now="$(date +%s)"
    _age="$(( _now - _started ))"
    log "another run is active (pid=${_pid:-unknown}, age=${_age}s); skipping this run"
    exit 0
  else
    rm -rf "${LOCK_DIR}" 2>/dev/null || true
    mkdir "${LOCK_DIR}" 2>/dev/null || die "failed to acquire lock: ${LOCK_DIR}"
  fi

  cat > "${LOCK_META}" <<EOF_LOCK
pid=$$
started_epoch=$(date +%s)
host=$(hostname 2>/dev/null || printf unknown)
prog=${0}
EOF_LOCK

  trap cleanup_lock EXIT HUP INT TERM
}

# Summary:
#   run_with_timeout helper.
run_with_timeout() {
  _label="$1"
  _timeout="$2"
  shift 2

  _timeout="$(num_or_default "${_timeout}" 0)"
  [ "${_timeout}" -gt 0 ] || die "invalid timeout for ${_label}: ${_timeout}"
  if ! command -v timeout >/dev/null 2>&1; then
    log "timeout command not found; running ${_label} without timeout"
    "$@"
    return $?
  fi

  if timeout -k "${TIMEOUT_KILL_GRACE_SECS}" "${_timeout}" "$@"; then
    return 0
  else
    _rc=$?
  fi

  if [ "${_rc}" -eq 124 ] || [ "${_rc}" -eq 137 ] || [ "${_rc}" -eq 143 ]; then
    die "${_label} exceeded timeout (${_timeout}s)"
  fi
  die "${_label} failed with exit code ${_rc}"
}

# Summary:
#   run_pipeline helper.
run_pipeline() {
  log "collect start (timeout=${COLLECT_TIMEOUT_SECS}s)"
  run_with_timeout collect "${COLLECT_TIMEOUT_SECS}" "${COLLECTOR}"
  log "collect done"

  log "render start (timeout=${RENDER_TIMEOUT_SECS}s)"
  run_with_timeout render "${RENDER_TIMEOUT_SECS}" "${RENDERER}"
  log "render done"

  if [ "${RUN_VERIFY}" -eq 1 ]; then
    log "verify start (timeout=${VERIFY_TIMEOUT_SECS}s)"
    run_with_timeout verify "${VERIFY_TIMEOUT_SECS}" "${VERIFIER}"
    log "verify done"
  fi
}

# Summary:
#   trigger_phase14_fast_path helper.
trigger_phase14_fast_path() {
  [ "${PHASE14_FAST_PATH_ENABLE}" -eq 1 ] || return 0
  if [ ! -x "${PHASE14_FAST_PATH_CMD}" ]; then
    log "phase-14 fast path skipped: missing ${PHASE14_FAST_PATH_CMD}"
    return 0
  fi

  log "phase-14 fast path start (timeout=${PHASE14_FAST_PATH_TIMEOUT_SECS}s)"
  if timeout -k "${TIMEOUT_KILL_GRACE_SECS}" "${PHASE14_FAST_PATH_TIMEOUT_SECS}" "${PHASE14_FAST_PATH_CMD}" --fast-path; then
    log "phase-14 fast path done"
    return 0
  fi

  _rc=$?
  log "phase-14 fast path failed (rc=${_rc})"
  return 0
}

RUN_VERIFY="$(num_or_default "${RUN_VERIFY}" 1)"
PHASE14_FAST_PATH_ENABLE="$(num_or_default "${PHASE14_FAST_PATH_ENABLE}" 1)"
PHASE14_FAST_PATH_TIMEOUT_SECS="$(num_or_default "${PHASE14_FAST_PATH_TIMEOUT_SECS}" 240)"
COLLECT_TIMEOUT_SECS="$(num_or_default "${COLLECT_TIMEOUT_SECS}" 300)"
RENDER_TIMEOUT_SECS="$(num_or_default "${RENDER_TIMEOUT_SECS}" 300)"
VERIFY_TIMEOUT_SECS="$(num_or_default "${VERIFY_TIMEOUT_SECS}" 180)"
TIMEOUT_KILL_GRACE_SECS="$(num_or_default "${TIMEOUT_KILL_GRACE_SECS}" 5)"
LOCK_STALE_SECS="$(num_or_default "${LOCK_STALE_SECS}" 960)"

need_exec "${COLLECTOR}"
need_exec "${RENDERER}"
[ "${RUN_VERIFY}" -eq 0 ] || need_exec "${VERIFIER}"

if [ "${INTERNAL_NOLOCK}" = "--no-lock" ]; then
  run_pipeline
  trigger_phase14_fast_path
  log "run complete"
  exit 0
fi

acquire_lock
run_pipeline
cleanup_lock
trap - EXIT HUP INT TERM
trigger_phase14_fast_path
log "run complete"
