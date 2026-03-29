#!/bin/ksh
#
# scripts/phases/phase-01-apply.ksh
#
# Public Phase 01 apply script for openbsd-mailstack.
#

set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing shared library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

SYSTEM_CONF="${PROJECT_ROOT}/config/system.conf"
NETWORK_CONF="${PROJECT_ROOT}/config/network.conf"
DOMAINS_CONF="${PROJECT_ROOT}/config/domains.conf"

SAVE_CONFIG="${SAVE_CONFIG:-no}"

usage() {
  cat <<'USAGEEOF'
Usage:
  ./scripts/phases/phase-01-apply.ksh

Optional environment variables:
  OPENBSD_MAILSTACK_NONINTERACTIVE=1   Disable prompts, fail if values are missing
  OPENBSD_MAILSTACK_INPUT_ROOT=/path   Override the default config/local input root
  SAVE_CONFIG=yes                      Save prompted values into config files
USAGEEOF
}

[ "${1:-}" = "--help" ] && { usage; exit 0; }

collect_inputs() {
  load_project_config

  prompt_value "OPENBSD_VERSION" "Enter the supported OpenBSD version for this deployment" "7.8"
  prompt_value "MAIL_HOSTNAME" "Enter the mail server hostname, example mail.example.com"
  prompt_value "PRIMARY_DOMAIN" "Enter the primary mail domain, example example.com"
  prompt_value "DOMAINS" "Enter the hosted domains as a space-separated list" "${PRIMARY_DOMAIN:-example.com}"

  prompt_value "LAN_INTERFACE" "Enter the LAN interface name, example em0"
  prompt_value "WAN_INTERFACE" "Enter the WAN interface name, example em1"
  prompt_value "LAN_IPV4" "Enter the LAN IPv4 address of the mail server"
  prompt_value "LAN_CIDR" "Enter the LAN CIDR prefix length, example 24" "24"
  prompt_value "ROUTER_LAN_IPV4" "Enter the router LAN IPv4 address"
  prompt_value "PUBLIC_IPV4" "Enter the public IPv4 address of the mail service"

  confirm_yes_no "DMZ_MODE" "Does your router use a DMZ host entry for this server" "no"
  prompt_value "DMZ_TARGET_IPV4" "Enter the DMZ target IPv4 address, usually the server LAN IP" "${LAN_IPV4}"

  prompt_value "PORT_FORWARD_TCP" "Enter public TCP ports as a space-separated list" "25 80 443"
  prompt_value "PORT_FORWARD_UDP" "Enter public UDP ports as a space-separated list" "51820"

  confirm_yes_no "ENABLE_HTTP" "Should TCP 80 be part of the planned public exposure" "yes"
  confirm_yes_no "ENABLE_HTTPS" "Should TCP 443 be part of the planned public exposure" "yes"
  confirm_yes_no "ENABLE_WIREGUARD" "Should WireGuard be part of the planned public exposure" "yes"

  if [ "${ENABLE_WIREGUARD}" = "yes" ]; then
    prompt_value "WIREGUARD_INTERFACE" "Enter the WireGuard interface name, example wg0" "wg0"
    prompt_value "WIREGUARD_SUBNET" "Enter the WireGuard subnet in CIDR format, example 10.44.0.0/24" "10.44.0.0/24"
    prompt_value "WIREGUARD_PORT" "Enter the public UDP port for WireGuard" "51820"
  else
    WIREGUARD_INTERFACE="${WIREGUARD_INTERFACE:-wg0}"
    WIREGUARD_SUBNET="${WIREGUARD_SUBNET:-10.44.0.0/24}"
    WIREGUARD_PORT="${WIREGUARD_PORT:-51820}"
  fi

  confirm_yes_no "PUBLIC_SSH" "Should SSH be reachable from the public Internet" "no"
  prompt_value "PUBLIC_SSH_PORT" "Enter the SSH port number if public SSH is allowed" "22"
  confirm_yes_no "ADMIN_VPN_ONLY" "Should administrative access remain VPN-only" "yes"
}

validate_inputs() {
  require_valid_hostname "MAIL_HOSTNAME"
  require_valid_domain "PRIMARY_DOMAIN"
  require_valid_ipv4 "LAN_IPV4"
  require_valid_ipv4 "ROUTER_LAN_IPV4"
  require_valid_ipv4 "PUBLIC_IPV4"

  print -- "${LAN_CIDR}" | grep -Eq '^[0-9]+$' || die "LAN_CIDR must be numeric, got: ${LAN_CIDR}"
  [ "${LAN_CIDR}" -ge 1 ] && [ "${LAN_CIDR}" -le 32 ] || die "LAN_CIDR must be between 1 and 32, got: ${LAN_CIDR}"

  print -- "${LAN_INTERFACE}" | grep -Eq '^[a-zA-Z0-9._-]+$' || die "invalid LAN interface name: ${LAN_INTERFACE}"
  print -- "${WAN_INTERFACE}" | grep -Eq '^[a-zA-Z0-9._-]+$' || die "invalid WAN interface name: ${WAN_INTERFACE}"

  _normalized_domains="$(normalize_space_list "${DOMAINS}")"
  [ -n "${_normalized_domains}" ] || die "DOMAINS must not be empty"
  DOMAINS="${_normalized_domains}"
  export DOMAINS

  _primary_found="no"
  for _domain in ${DOMAINS}; do
    validate_domain "${_domain}" || die "invalid domain in DOMAINS: ${_domain}"
    [ "${_domain}" = "${PRIMARY_DOMAIN}" ] && _primary_found="yes"
  done
  [ "${_primary_found}" = "yes" ] || die "PRIMARY_DOMAIN must also appear in DOMAINS"

  case "${DMZ_MODE}" in yes|no) ;; *) die "DMZ_MODE must be yes or no" ;; esac
  case "${ENABLE_HTTP}" in yes|no) ;; *) die "ENABLE_HTTP must be yes or no" ;; esac
  case "${ENABLE_HTTPS}" in yes|no) ;; *) die "ENABLE_HTTPS must be yes or no" ;; esac
  case "${ENABLE_WIREGUARD}" in yes|no) ;; *) die "ENABLE_WIREGUARD must be yes or no" ;; esac
  case "${PUBLIC_SSH}" in yes|no) ;; *) die "PUBLIC_SSH must be yes or no" ;; esac
  case "${ADMIN_VPN_ONLY}" in yes|no) ;; *) die "ADMIN_VPN_ONLY must be yes or no" ;; esac

  validate_port_list "${PORT_FORWARD_TCP}" || die "PORT_FORWARD_TCP must be a space-separated list of valid ports"
  validate_port_list "${PORT_FORWARD_UDP}" || die "PORT_FORWARD_UDP must be a space-separated list of valid ports"
  validate_port "${PUBLIC_SSH_PORT}" || die "PUBLIC_SSH_PORT must be a valid port number"

  PORT_FORWARD_TCP="$(normalize_space_list "${PORT_FORWARD_TCP}")"
  PORT_FORWARD_UDP="$(normalize_space_list "${PORT_FORWARD_UDP}")"
  export PORT_FORWARD_TCP PORT_FORWARD_UDP

  if [ "${DMZ_MODE}" = "yes" ] && [ "${DMZ_TARGET_IPV4}" != "${LAN_IPV4}" ]; then
    log_warn "DMZ target ${DMZ_TARGET_IPV4} does not match LAN IPv4 ${LAN_IPV4}"
  fi

  if [ "${ENABLE_WIREGUARD}" = "yes" ]; then
    print -- "${WIREGUARD_INTERFACE}" | grep -Eq '^[a-zA-Z0-9._-]+$' || die "invalid WireGuard interface name: ${WIREGUARD_INTERFACE}"
    validate_ipv4_cidr "${WIREGUARD_SUBNET}" || die "invalid WireGuard subnet: ${WIREGUARD_SUBNET}"
    validate_port "${WIREGUARD_PORT}" || die "invalid WireGuard port: ${WIREGUARD_PORT}"
  fi

  if [ "${PUBLIC_SSH}" = "yes" ] && [ "${ADMIN_VPN_ONLY}" = "yes" ]; then
    log_warn "PUBLIC_SSH is yes while ADMIN_VPN_ONLY is also yes, review this policy choice"
  fi
}

save_configs_if_requested() {
  [ "${SAVE_CONFIGS}" = "yes" ] || return 0

  mkdir -p "${CONFIG_DIR}"
  if [ ! -f "${SYSTEM_CONF}" ] && [ -f "${CONFIG_DIR}/system.conf.example" ]; then
    cp "${CONFIG_DIR}/system.conf.example" "${SYSTEM_CONF}"
  fi
  if [ ! -f "${SECRETS_CONF}" ] && [ -f "${CONFIG_DIR}/secrets.conf.example" ]; then
    cp "${CONFIG_DIR}/secrets.conf.example" "${SECRETS_CONF}"
  fi

  write_named_config "${NETWORK_CONF}"     "LAN_INTERFACE" "${LAN_INTERFACE}"     "WAN_INTERFACE" "${WAN_INTERFACE}"     "LAN_IPV4" "${LAN_IPV4}"     "LAN_CIDR" "${LAN_CIDR}"     "ROUTER_LAN_IPV4" "${ROUTER_LAN_IPV4}"     "PUBLIC_IPV4" "${PUBLIC_IPV4}"     "DMZ_MODE" "${DMZ_MODE}"     "DMZ_TARGET_IPV4" "${DMZ_TARGET_IPV4}"     "PORT_FORWARD_TCP" "${PORT_FORWARD_TCP}"     "PORT_FORWARD_UDP" "${PORT_FORWARD_UDP}"     "ENABLE_HTTP" "${ENABLE_HTTP}"     "ENABLE_HTTPS" "${ENABLE_HTTPS}"     "ENABLE_WIREGUARD" "${ENABLE_WIREGUARD}"     "WIREGUARD_INTERFACE" "${WIREGUARD_INTERFACE}"     "WIREGUARD_SUBNET" "${WIREGUARD_SUBNET}"     "WIREGUARD_PORT" "${WIREGUARD_PORT}"     "PUBLIC_SSH" "${PUBLIC_SSH}"     "PUBLIC_SSH_PORT" "${PUBLIC_SSH_PORT}"     "ADMIN_VPN_ONLY" "${ADMIN_VPN_ONLY}"

  write_named_config "${DOMAINS_CONF}"     "PRIMARY_DOMAIN" "${PRIMARY_DOMAIN}"     "DOMAINS" "${DOMAINS}"

  log "Saved network settings to ${NETWORK_CONF}"
}

check_commands() {
  require_command uname
  require_command ifconfig
  require_command route
  require_command netstat
  require_command awk
  require_command grep
  require_command sed
}

check_baseline() {
  ensure_openbsd
  ensure_openbsd_version "${OPENBSD_VERSION}"

  if ifconfig "${LAN_INTERFACE}" >/dev/null 2>&1; then
    log_info "LAN interface detected: ${LAN_INTERFACE}"
  else
    die "LAN interface not found: ${LAN_INTERFACE}"
  fi

  if ifconfig "${WAN_INTERFACE}" >/dev/null 2>&1; then
    log_info "WAN interface detected: ${WAN_INTERFACE}"
  else
    die "WAN interface not found: ${WAN_INTERFACE}"
  fi
}

print_router_checklist() {
  print
  print -- "Router and exposure checklist"
  print -- "  Mail host LAN address : ${LAN_IPV4}/${LAN_CIDR}"
  print -- "  Router LAN address    : ${ROUTER_LAN_IPV4}"
  print -- "  Public IPv4           : ${PUBLIC_IPV4}"
  print -- "  DMZ mode              : ${DMZ_MODE}"
  print -- "  DMZ target            : ${DMZ_TARGET_IPV4}"
  print -- "  Public TCP ports      : ${PORT_FORWARD_TCP:-none}"
  print -- "  Public UDP ports      : ${PORT_FORWARD_UDP:-none}"
  print -- "  Public SSH            : ${PUBLIC_SSH}"
  print -- "  Admin VPN only        : ${ADMIN_VPN_ONLY}"
  print -- "  Hosted domains        : ${DOMAINS}"
  print
  print -- "Router actions to complete outside this script"
  if [ "${DMZ_MODE}" = "yes" ]; then
    print -- "  1. Configure the router DMZ target to ${DMZ_TARGET_IPV4}."
    print -- "  2. Confirm the OpenBSD host firewall only allows required services."
  else
    print -- "  1. Configure explicit TCP port forwards to ${LAN_IPV4}: ${PORT_FORWARD_TCP:-none}."
    print -- "  2. Configure explicit UDP port forwards to ${LAN_IPV4}: ${PORT_FORWARD_UDP:-none}."
  fi
  if [ "${PUBLIC_SSH}" = "yes" ]; then
    print -- "  3. Review whether public SSH on port ${PUBLIC_SSH_PORT} is truly required."
  else
    print -- "  3. Keep SSH reachable through WireGuard only, if practical."
  fi
  print -- "  4. Keep admin web interfaces VPN-only in later phases."
  print -- "  5. Remember that multiple domains reuse the same host and exposure policy."
  print
}

main() {
  print_phase_header "PHASE-01" "network and external access"
  collect_inputs
  validate_inputs
  save_configs_if_requested
  check_commands
  check_baseline
  print_router_checklist
  log_info "phase 01 network and external access planning completed successfully"
  log_info "next step: run ./scripts/phases/phase-01-verify.ksh"
}

main "$@"
