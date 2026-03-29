#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${PROJECT_ROOT}/scripts/lib/network-exposure.ksh"

FAIL_COUNT=0
WARN_COUNT=0

pass() { print -- "[$(timestamp)] PASS  $*"; }
warn() { print -- "[$(timestamp)] WARN  $*"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { print -- "[$(timestamp)] FAIL  $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

check_file() {
  _path="$1"
  if [ -f "${_path}" ]; then
    pass "found ${_path}"
  else
    fail "missing ${_path}"
  fi
}

main() {
  load_network_exposure_config
  validate_network_exposure_inputs && pass "network exposure inputs are valid"
  render_root="${PROJECT_ROOT}/services/generated/rootfs"
  check_file "${render_root}/etc/pf.conf"
  check_file "${render_root}/etc/pf.anchors/openbsd-mailstack-selfhost"
  if [ "${ENABLE_WIREGUARD}" = "yes" ]; then
    check_file "${render_root}/etc/hostname.${WIREGUARD_INTERFACE}"
  fi
  if [ "${UNBOUND_ENABLED}" = "yes" ]; then
    check_file "${render_root}/var/unbound/etc/unbound.conf"
    check_file "${render_root}/var/unbound/etc/conf.d/mailstack-zones.conf"
  fi
  if [ "${DDNS_ENABLED}" = "yes" ]; then
    check_file "${render_root}/usr/local/bin/vultr_ddns_sync.py"
  fi
  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  [ "${FAIL_COUNT}" -eq 0 ]
}

main "$@"
