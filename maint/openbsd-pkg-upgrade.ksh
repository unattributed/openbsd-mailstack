#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

ACTION="${1:-}"
PKG_ADD_TIMEOUT_SECS="${PKG_ADD_TIMEOUT_SECS:-1800}"
ALLOW_PKG_TIMEOUT_CONTINUE="${ALLOW_PKG_TIMEOUT_CONTINUE:-0}"

ts() { date "+%Y-%m-%dT%H:%M:%S%z"; }
log() { print -- "[$(ts)] $*"; }
need_root() { [ "$(id -u)" -eq 0 ] || { print -- "error: must run as root via doas" >&2; exit 1; }; }

run_pkg_add() {
  if command -v timeout >/dev/null 2>&1; then
    timeout -k 5 "${PKG_ADD_TIMEOUT_SECS}" pkg_add -u -I
    return $?
  fi
  pkg_add -u -I
}

need_root
[ -f /etc/installurl ] || { print -- "error: /etc/installurl missing" >&2; exit 1; }
case "${ACTION}" in
  --check)
    log "installurl"
    cat /etc/installurl
    log "package snapshot"
    pkg_info -q | sort
    ;;
  --apply)
    log "running pkg_add -u -I"
    if ! run_pkg_add; then
      _rc=$?
      if [ "${_rc}" -eq 124 ] && [ "${ALLOW_PKG_TIMEOUT_CONTINUE}" = "1" ]; then
        log "pkg_add timed out, continuing because ALLOW_PKG_TIMEOUT_CONTINUE=1"
        exit 0
      fi
      exit "${_rc}"
    fi
    if command -v pkg_check-problems >/dev/null 2>&1; then
      pkg_check-problems || true
    fi
    ;;
  *)
    print -- "usage: $0 [--check|--apply]" >&2
    exit 2
    ;;
esac
