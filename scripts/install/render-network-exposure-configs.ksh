#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${PROJECT_ROOT}/scripts/lib/network-exposure.ksh"

OUTPUT_ROOT="${OUTPUT_ROOT:-${PROJECT_ROOT}/services/generated/rootfs}"
SAVE_CONFIG="${SAVE_CONFIG:-no}"

collect_missing_inputs() {
  load_network_exposure_config
  prompt_value "MAIL_HOSTNAME" "Enter the public mail hostname" "${MAIL_HOSTNAME}"
  prompt_value "PRIMARY_DOMAIN" "Enter the primary domain" "${PRIMARY_DOMAIN}"
  prompt_value "DOMAINS" "Enter hosted domains separated by spaces" "${DOMAINS}"
  prompt_value "LAN_INTERFACE" "Enter the LAN interface" "${LAN_INTERFACE}"
  prompt_value "WAN_INTERFACE" "Enter the WAN interface or macro, example egress" "${WAN_INTERFACE}"
  prompt_value "LAN_IPV4" "Enter the LAN IPv4 address" "${LAN_IPV4}"
  prompt_value "ROUTER_LAN_IPV4" "Enter the router LAN IPv4 address" "${ROUTER_LAN_IPV4}"
  prompt_value "PUBLIC_IPV4" "Enter the public IPv4 address" "${PUBLIC_IPV4}"
  confirm_yes_no "ENABLE_WIREGUARD" "Enable WireGuard" "${ENABLE_WIREGUARD}"
  if [ "${ENABLE_WIREGUARD}" = "yes" ]; then
    prompt_value "WIREGUARD_INTERFACE" "Enter the WireGuard interface" "${WIREGUARD_INTERFACE}"
    prompt_value "WIREGUARD_SERVER_IPV4" "Enter the WireGuard server address" "${WIREGUARD_SERVER_IPV4}"
    prompt_value "WIREGUARD_SUBNET" "Enter the WireGuard subnet" "${WIREGUARD_SUBNET}"
    prompt_value "WIREGUARD_PORT" "Enter the WireGuard listen port" "${WIREGUARD_PORT}"
  fi
  prompt_value "DNS_PROVIDER" "Enter the DNS provider name" "${DNS_PROVIDER}"
  confirm_yes_no "DDNS_ENABLED" "Enable DDNS helper rendering" "${DDNS_ENABLED}"
  if [ "${DDNS_ENABLED}" = "yes" ]; then
    prompt_value "DDNS_PROVIDER" "Enter the DDNS provider name" "${DDNS_PROVIDER}"
    prompt_value "DDNS_TARGET_IPV4" "Enter the DDNS target IPv4" "${DDNS_TARGET_IPV4}"
    prompt_value "DDNS_DOMAINS" "Enter DDNS domains separated by spaces" "${DDNS_DOMAINS}"
    prompt_value "DDNS_HOST_LABELS" "Enter DDNS host labels separated by spaces" "${DDNS_HOST_LABELS}"
  fi
}

main() {
  print_phase_header "PHASE-07" "render network exposure configs"
  collect_missing_inputs
  validate_network_exposure_inputs
  if [ "${SAVE_CONFIG}" = "yes" ]; then
    save_network_exposure_configs
    log_info "saved network, dns, and ddns config files"
  fi
  render_network_exposure_tree "${OUTPUT_ROOT}"
  log_info "rendered network exposure assets to ${OUTPUT_ROOT}"
}

main "$@"
