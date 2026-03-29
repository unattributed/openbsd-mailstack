#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${PROJECT_ROOT}/scripts/lib/network-exposure.ksh"

MODE="${1:---dry-run}"
case "${MODE}" in
  --dry-run|--apply) ;;
  *) die "usage: $0 --dry-run | --apply" ;;
esac

render_root="${PROJECT_ROOT}/services/generated/rootfs"
timestamp_id="$(date -u +%Y%m%dT%H%M%SZ)"
backup_root="/var/backups/openbsd-mailstack/network-exposure/${timestamp_id}"

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    doas -n "$@"
  fi
}

install_file() {
  _src="$1"
  _dst="$2"
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "DRY-RUN install ${_src} -> ${_dst}"
    return 0
  fi
  as_root mkdir -p "$(dirname -- "${_dst}")"
  if as_root test -e "${_dst}"; then
    as_root mkdir -p "${backup_root}"
    as_root cp -p "${_dst}" "${backup_root}/$(echo "${_dst}" | tr '/' '_')"
  fi
  as_root cp -p "${_src}" "${_dst}"
}

main() {
  load_network_exposure_config
  validate_network_exposure_inputs
  "${PROJECT_ROOT}/scripts/install/render-network-exposure-configs.ksh"
  install_file "${render_root}/etc/pf.conf" "/etc/pf.conf"
  install_file "${render_root}/etc/pf.anchors/openbsd-mailstack-selfhost" "/etc/pf.anchors/openbsd-mailstack-selfhost"
  if [ -f "${render_root}/etc/hostname.${WIREGUARD_INTERFACE}" ]; then
    install_file "${render_root}/etc/hostname.${WIREGUARD_INTERFACE}" "/etc/hostname.${WIREGUARD_INTERFACE}"
  fi
  if [ -f "${render_root}/var/unbound/etc/unbound.conf" ]; then
    install_file "${render_root}/var/unbound/etc/unbound.conf" "/var/unbound/etc/unbound.conf"
  fi
  if [ -f "${render_root}/var/unbound/etc/conf.d/mailstack-zones.conf" ]; then
    install_file "${render_root}/var/unbound/etc/conf.d/mailstack-zones.conf" "/var/unbound/etc/conf.d/mailstack-zones.conf"
  fi
  if [ -f "${render_root}/usr/local/bin/vultr_ddns_sync.py" ]; then
    install_file "${render_root}/usr/local/bin/vultr_ddns_sync.py" "/usr/local/bin/vultr_ddns_sync.py"
  fi
  if [ -f "${render_root}/etc/examples/openbsd-mailstack/ddns.env" ]; then
    install_file "${render_root}/etc/examples/openbsd-mailstack/ddns.env" "/etc/examples/openbsd-mailstack/ddns.env"
  fi
  log_info "network exposure install ${MODE#--} completed"
}

main "$@"
