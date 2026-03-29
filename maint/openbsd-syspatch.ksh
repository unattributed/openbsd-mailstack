#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

ACTION="${1:-}"
SYSPATCH_FALLBACK_URL="${SYSPATCH_FALLBACK_URL:-https://cdn.openbsd.org/pub/OpenBSD}"

ts() { date "+%Y-%m-%dT%H:%M:%S%z"; }
log() { print -- "[$(ts)] $*"; }
need_root() { [ "$(id -u)" -eq 0 ] || { print -- "error: must run as root via doas" >&2; exit 1; }; }

normalize_installurl() {
  _url="${1:-}"
  _osrel="$(sysctl -n kern.osrelease 2>/dev/null || true)"
  _url="${_url%/}"
  if [ -n "${_url}" ] && [ -n "${_osrel}" ]; then
    case "${_url}" in
      */"${_osrel}") _url="${_url%/${_osrel}}" ;;
    esac
  fi
  print -- "${_url}"
}

run_syspatch() {
  _installurl_orig="$(cat /etc/installurl 2>/dev/null || true)"
  _normalized="$(normalize_installurl "${_installurl_orig}")"
  if [ -n "${_normalized}" ] && [ "${_normalized}" != "${_installurl_orig%/}" ]; then
    print -- "${_normalized}" > /etc/installurl
  fi
  if syspatch "$@"; then
    _rc=0
  else
    _rc=$?
  fi
  if [ -n "${_installurl_orig}" ]; then
    print -- "${_installurl_orig}" > /etc/installurl
  fi
  return "${_rc}"
}

need_root
case "${ACTION}" in
  --check)
    log "checking for available syspatches"
    run_syspatch -c || true
    log "installed syspatches"
    syspatch -l || true
    ;;
  --apply)
    log "applying syspatches"
    if ! run_syspatch; then
      log "primary syspatch attempt failed, trying fallback installurl ${SYSPATCH_FALLBACK_URL}"
      print -- "${SYSPATCH_FALLBACK_URL}" > /etc/installurl
      syspatch
    fi
    ;;
  *)
    print -- "usage: $0 [--check|--apply]" >&2
    exit 2
    ;;
esac
