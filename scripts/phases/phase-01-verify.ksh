#!/bin/ksh
#
# scripts/phases/phase-01-verify.ksh
#
# Public Phase 01 verify script for openbsd-mailstack.
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

FAIL_COUNT=0
WARN_COUNT=0

pass() {
  print -- "[$(timestamp)] PASS  $*"
}

warn() {
  print -- "[$(timestamp)] WARN  $*"
  WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
  print -- "[$(timestamp)] FAIL  $*"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

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
  prompt_value "WIREGUARD_INTERFACE" "Enter the WireGuard interface name, example wg0" "wg0"
  prompt_value "WIREGUARD_SUBNET" "Enter the WireGuard subnet in CIDR format, example 10.44.0.0/24" "10.44.0.0/24"
  prompt_value "WIREGUARD_PORT" "Enter the public UDP port for WireGuard" "51820"

  confirm_yes_no "PUBLIC_SSH" "Should SSH be reachable from the public Internet" "no"
  prompt_value "PUBLIC_SSH_PORT" "Enter the SSH port number if public SSH is allowed" "22"
  confirm_yes_no "ADMIN_VPN_ONLY" "Should administrative access remain VPN-only" "yes"
}

validate_inputs() {
  validate_hostname "${MAIL_HOSTNAME}" && pass "MAIL_HOSTNAME is valid: ${MAIL_HOSTNAME}" || fail "MAIL_HOSTNAME is invalid: ${MAIL_HOSTNAME:-<empty>}"
  validate_domain "${PRIMARY_DOMAIN}" && pass "PRIMARY_DOMAIN is valid: ${PRIMARY_DOMAIN}" || fail "PRIMARY_DOMAIN is invalid: ${PRIMARY_DOMAIN:-<empty>}"
  validate_ipv4 "${LAN_IPV4}" && pass "LAN_IPV4 is valid: ${LAN_IPV4}" || fail "LAN_IPV4 is invalid: ${LAN_IPV4:-<empty>}"
  validate_ipv4 "${ROUTER_LAN_IPV4}" && pass "ROUTER_LAN_IPV4 is valid: ${ROUTER_LAN_IPV4}" || fail "ROUTER_LAN_IPV4 is invalid: ${ROUTER_LAN_IPV4:-<empty>}"
  validate_ipv4 "${PUBLIC_IPV4}" && pass "PUBLIC_IPV4 is valid: ${PUBLIC_IPV4}" || fail "PUBLIC_IPV4 is invalid: ${PUBLIC_IPV4:-<empty>}"

  print -- "${LAN_CIDR}" | grep -Eq '^[0-9]+$' && [ "${LAN_CIDR}" -ge 1 ] && [ "${LAN_CIDR}" -le 32 ] \
    && pass "LAN_CIDR is valid: ${LAN_CIDR}" \
    || fail "LAN_CIDR is invalid: ${LAN_CIDR:-<empty>}"

  DOMAINS="$(normalize_space_list "${DOMAINS}")"
  [ -n "${DOMAINS}" ] && pass "DOMAINS is not empty" || fail "DOMAINS must not be empty"

  _primary_found="no"
  for _domain in ${DOMAINS}; do
    if validate_domain "${_domain}"; then
      pass "hosted domain is valid: ${_domain}"
    else
      fail "hosted domain is invalid: ${_domain}"
    fi
    [ "${_domain}" = "${PRIMARY_DOMAIN}" ] && _primary_found="yes"
  done
  [ "${_primary_found}" = "yes" ] && pass "PRIMARY_DOMAIN is present in DOMAINS" || fail "PRIMARY_DOMAIN must also appear in DOMAINS"

  validate_port_list "${PORT_FORWARD_TCP}" && pass "PORT_FORWARD_TCP is valid: ${PORT_FORWARD_TCP}" || fail "PORT_FORWARD_TCP is invalid: ${PORT_FORWARD_TCP:-<empty>}"
  validate_port_list "${PORT_FORWARD_UDP}" && pass "PORT_FORWARD_UDP is valid: ${PORT_FORWARD_UDP}" || fail "PORT_FORWARD_UDP is invalid: ${PORT_FORWARD_UDP:-<empty>}"
  validate_port "${PUBLIC_SSH_PORT}" && pass "PUBLIC_SSH_PORT is valid: ${PUBLIC_SSH_PORT}" || fail "PUBLIC_SSH_PORT is invalid: ${PUBLIC_SSH_PORT:-<empty>}"

  if [ "${ENABLE_WIREGUARD}" = "yes" ]; then
    validate_ipv4_cidr "${WIREGUARD_SUBNET}" && pass "WIREGUARD_SUBNET is valid: ${WIREGUARD_SUBNET}" || fail "WIREGUARD_SUBNET is invalid: ${WIREGUARD_SUBNET:-<empty>}"
    validate_port "${WIREGUARD_PORT}" && pass "WIREGUARD_PORT is valid: ${WIREGUARD_PORT}" || fail "WIREGUARD_PORT is invalid: ${WIREGUARD_PORT:-<empty>}"
  fi

  [ "${DMZ_MODE}" = "yes" ] || [ "${DMZ_MODE}" = "no" ] && pass "DMZ_MODE is valid: ${DMZ_MODE}" || fail "DMZ_MODE is invalid: ${DMZ_MODE:-<empty>}"
  [ "${ENABLE_HTTP}" = "yes" ] || [ "${ENABLE_HTTP}" = "no" ] && pass "ENABLE_HTTP is valid: ${ENABLE_HTTP}" || fail "ENABLE_HTTP is invalid: ${ENABLE_HTTP:-<empty>}"
  [ "${ENABLE_HTTPS}" = "yes" ] || [ "${ENABLE_HTTPS}" = "no" ] && pass "ENABLE_HTTPS is valid: ${ENABLE_HTTPS}" || fail "ENABLE_HTTPS is invalid: ${ENABLE_HTTPS:-<empty>}"
  [ "${ENABLE_WIREGUARD}" = "yes" ] || [ "${ENABLE_WIREGUARD}" = "no" ] && pass "ENABLE_WIREGUARD is valid: ${ENABLE_WIREGUARD}" || fail "ENABLE_WIREGUARD is invalid: ${ENABLE_WIREGUARD:-<empty>}"
  [ "${PUBLIC_SSH}" = "yes" ] || [ "${PUBLIC_SSH}" = "no" ] && pass "PUBLIC_SSH is valid: ${PUBLIC_SSH}" || fail "PUBLIC_SSH is invalid: ${PUBLIC_SSH:-<empty>}"
  [ "${ADMIN_VPN_ONLY}" = "yes" ] || [ "${ADMIN_VPN_ONLY}" = "no" ] && pass "ADMIN_VPN_ONLY is valid: ${ADMIN_VPN_ONLY}" || fail "ADMIN_VPN_ONLY is invalid: ${ADMIN_VPN_ONLY:-<empty>}"
}

check_commands() {
  for cmd in uname ifconfig route netstat awk grep sed; do
    if command_exists "${cmd}"; then
      pass "required command present: ${cmd}"
    else
      fail "required command missing: ${cmd}"
    fi
  done
}

check_host_state() {
  _os="$(uname -s 2>/dev/null || true)"
  _version="$(uname -r 2>/dev/null || true)"

  [ "${_os}" = "OpenBSD" ] && pass "operating system is OpenBSD" || fail "operating system is not OpenBSD, detected ${_os:-unknown}"
  [ "${_version}" = "${OPENBSD_VERSION}" ] && pass "OpenBSD version matches expected ${OPENBSD_VERSION}" || fail "OpenBSD version mismatch, expected ${OPENBSD_VERSION}, detected ${_version:-unknown}"

  if ifconfig "${LAN_INTERFACE}" >/dev/null 2>&1; then
    pass "LAN interface exists: ${LAN_INTERFACE}"
  else
    fail "LAN interface not found: ${LAN_INTERFACE}"
  fi

  if ifconfig "${WAN_INTERFACE}" >/dev/null 2>&1; then
    pass "WAN interface exists: ${WAN_INTERFACE}"
  else
    fail "WAN interface not found: ${WAN_INTERFACE}"
  fi

  if ifconfig "${LAN_INTERFACE}" 2>/dev/null | grep -q "inet ${LAN_IPV4} "; then
    pass "LAN interface has expected IPv4 assigned: ${LAN_IPV4}"
  else
    warn "LAN interface does not currently show expected IPv4 ${LAN_IPV4}"
  fi

  if route -n show default 2>/dev/null | grep -q 'gateway:'; then
    pass "default route is present"
  else
    warn "default route not detected"
  fi
}

check_policy_consistency() {
  if [ "${DMZ_MODE}" = "yes" ] && [ "${DMZ_TARGET_IPV4}" = "${LAN_IPV4}" ]; then
    pass "DMZ target matches LAN IPv4"
  elif [ "${DMZ_MODE}" = "yes" ]; then
    warn "DMZ mode is enabled but DMZ target ${DMZ_TARGET_IPV4} does not match LAN IPv4 ${LAN_IPV4}"
  else
    pass "DMZ mode is disabled, explicit port forwarding is expected"
  fi

  if [ "${PUBLIC_SSH}" = "yes" ]; then
    warn "public SSH is enabled on port ${PUBLIC_SSH_PORT}, review this exposure carefully"
  else
    pass "public SSH is disabled"
  fi

  if [ "${ADMIN_VPN_ONLY}" = "yes" ]; then
    pass "administrative access is marked VPN-only"
  else
    warn "administrative access is not marked VPN-only"
  fi

  if [ "${ENABLE_HTTP}" = "yes" ] && print -- "${PORT_FORWARD_TCP}" | grep -Eq '(^| )80( |$)'; then
    pass "TCP 80 exposure is consistent with ENABLE_HTTP=yes"
  elif [ "${ENABLE_HTTP}" = "yes" ]; then
    warn "ENABLE_HTTP=yes but TCP 80 is not listed in PORT_FORWARD_TCP"
  fi

  if [ "${ENABLE_HTTPS}" = "yes" ] && print -- "${PORT_FORWARD_TCP}" | grep -Eq '(^| )443( |$)'; then
    pass "TCP 443 exposure is consistent with ENABLE_HTTPS=yes"
  elif [ "${ENABLE_HTTPS}" = "yes" ]; then
    warn "ENABLE_HTTPS=yes but TCP 443 is not listed in PORT_FORWARD_TCP"
  fi

  if [ "${ENABLE_WIREGUARD}" = "yes" ] && print -- "${PORT_FORWARD_UDP}" | grep -Eq "(^| )${WIREGUARD_PORT}( |$)"; then
    pass "WireGuard UDP exposure is consistent with ENABLE_WIREGUARD=yes"
  elif [ "${ENABLE_WIREGUARD}" = "yes" ]; then
    warn "ENABLE_WIREGUARD=yes but UDP ${WIREGUARD_PORT} is not listed in PORT_FORWARD_UDP"
  fi
}

print_result() {
  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  print

  if [ "${FAIL_COUNT}" -gt 0 ]; then
    exit 1
  fi
  exit 0
}

main() {
  print_phase_header "PHASE-01" "network and external access verification"
  collect_inputs
  validate_inputs
  check_commands
  check_host_state
  check_policy_consistency
  print_result
}

main "$@"
