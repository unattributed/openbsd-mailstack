#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

ACTION="${1:-}"

ts() { date "+%Y-%m-%dT%H:%M:%S%z"; }
log() { print -- "[$(ts)] $*"; }
need_root() { [ "$(id -u)" -eq 0 ] || { print -- "error: must run as root via doas" >&2; exit 1; }; }

need_root
[ "$(sysctl -n kern.osrelease)" = "7.9" ] || {
  print -- "error: this maintenance baseline requires OpenBSD 7.9" >&2
  exit 1
}
[ -s /etc/installurl ] || {
  print -- "error: /etc/installurl is missing or empty" >&2
  exit 1
}

case "${ACTION}" in
  --check)
    log "checking for available syspatches"
    syspatch -c
    log "installed syspatches"
    syspatch -l
    ;;
  --apply)
    log "applying syspatches"
    set +e
    syspatch
    _rc=$?
    set -e
    [ "${_rc}" -eq 0 ] || [ "${_rc}" -eq 2 ] || exit "${_rc}"
    [ "${_rc}" -eq 2 ] && log "no additional syspatch was installed"
    ;;
  *)
    print -- "usage: $0 [--check|--apply]" >&2
    exit 2
    ;;
esac
