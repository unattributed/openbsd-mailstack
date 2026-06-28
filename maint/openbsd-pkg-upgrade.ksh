#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

ACTION="${1:-}"
PKG_ADD_TIMEOUT_SECS="${PKG_ADD_TIMEOUT_SECS:-1800}"
ALLOW_PKG_TIMEOUT_CONTINUE="${ALLOW_PKG_TIMEOUT_CONTINUE:-0}"

ts() { date "+%Y-%m-%dT%H:%M:%S%z"; }
log() { print -- "[$(ts)] $*"; }
need_root() { [ "$(id -u)" -eq 0 ] || { print -- "error: must run as root via doas" >&2; exit 1; }; }

run_bounded() {
  "$@" &
  _command_pid=$!
  (
    sleep "${PKG_ADD_TIMEOUT_SECS}"
    kill -INT "${_command_pid}" 2>/dev/null || true
  ) &
  _watchdog_pid=$!

  set +e
  wait "${_command_pid}"
  _rc=$?
  set -e
  kill "${_watchdog_pid}" 2>/dev/null || true
  wait "${_watchdog_pid}" 2>/dev/null || true
  [ "${_rc}" -eq 130 ] && return 124
  return "${_rc}"
}

run_pkg_add() {
  run_bounded pkg_add -u -I
}

run_pkg_preview() {
  run_bounded pkg_add -u -n -I
}

need_root
[ -f /etc/installurl ] || { print -- "error: /etc/installurl missing" >&2; exit 1; }
[ "$(sysctl -n kern.osrelease)" = "7.9" ] || {
  print -- "error: this maintenance baseline requires OpenBSD 7.9" >&2
  exit 1
}
case "${ACTION}" in
  --check)
    log "previewing package updates"
    run_pkg_preview
    log "validating installed package consistency without repair"
    pkg_check -n -I
    ;;
  --apply)
    log "running pkg_add -u -I"
    set +e
    run_pkg_add
    _rc=$?
    set -e
    if [ "${_rc}" -ne 0 ]; then
      if [ "${_rc}" -eq 124 ] && [ "${ALLOW_PKG_TIMEOUT_CONTINUE}" = "1" ]; then
        log "pkg_add timed out; package state must still pass pkg_check"
      else
        exit "${_rc}"
      fi
    fi
    log "validating installed package consistency without repair"
    pkg_check -n -I
    ;;
  *)
    print -- "usage: $0 [--check|--apply]" >&2
    exit 2
    ;;
esac
