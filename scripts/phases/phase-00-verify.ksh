#!/bin/ksh
#
# scripts/phases/phase-00-verify.ksh
#
# Public Phase 00 verify script for openbsd-mailstack.
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
  prompt_value "DOMAINS" "Enter all hosted domains as a space-separated list, example example.com example.net example.org" "${PRIMARY_DOMAIN:-example.com}"
  prompt_value "ADMIN_EMAIL" "Enter the administrator email address, example ops@example.com"
  prompt_value "PUBLIC_IPV4" "Enter the public IPv4 address of the mail server"
  prompt_value "LAN_INTERFACE" "Enter the LAN interface name, example em0"
  prompt_value "WAN_INTERFACE" "Enter the WAN interface name, example em1"
  prompt_value "LAN_IPV4" "Enter the LAN IPv4 address of the server"
  prompt_value "LAN_CIDR" "Enter the LAN CIDR prefix length, example 24" "24"
  confirm_yes_no "ENABLE_WIREGUARD" "Do you plan to use WireGuard with this project" "yes"

  if [ "${ENABLE_WIREGUARD}" = "yes" ]; then
    prompt_value "WIREGUARD_INTERFACE" "Enter the WireGuard interface name, example wg0" "wg0"
    prompt_value "WIREGUARD_SUBNET" "Enter the WireGuard subnet in CIDR format, example 10.44.0.0/24" "10.44.0.0/24"
  fi
}

validate_domain_list() {
  _domain_list="$1"
  [ -n "${_domain_list}" ] || return 1

  _found_primary="no"
  for _domain in ${_domain_list}; do
    validate_domain "${_domain}" || return 1
    if [ "${_domain}" = "${PRIMARY_DOMAIN}" ]; then
      _found_primary="yes"
    fi
  done

  [ "${_found_primary}" = "yes" ]
}

validate_inputs() {
  if validate_hostname "${MAIL_HOSTNAME}"; then
    pass "MAIL_HOSTNAME is valid: ${MAIL_HOSTNAME}"
  else
    fail "MAIL_HOSTNAME is invalid: ${MAIL_HOSTNAME:-<empty>}"
  fi

  if validate_domain "${PRIMARY_DOMAIN}"; then
    pass "PRIMARY_DOMAIN is valid: ${PRIMARY_DOMAIN}"
  else
    fail "PRIMARY_DOMAIN is invalid: ${PRIMARY_DOMAIN:-<empty>}"
  fi

  if validate_domain_list "${DOMAINS}"; then
    pass "DOMAINS list is valid and contains PRIMARY_DOMAIN: ${DOMAINS}"
  else
    fail "DOMAINS list is invalid or does not contain PRIMARY_DOMAIN: ${DOMAINS:-<empty>}"
  fi

  if validate_email "${ADMIN_EMAIL}"; then
    pass "ADMIN_EMAIL is valid: ${ADMIN_EMAIL}"
  else
    fail "ADMIN_EMAIL is invalid: ${ADMIN_EMAIL:-<empty>}"
  fi

  if validate_ipv4 "${PUBLIC_IPV4}"; then
    pass "PUBLIC_IPV4 is valid: ${PUBLIC_IPV4}"
  else
    fail "PUBLIC_IPV4 is invalid: ${PUBLIC_IPV4:-<empty>}"
  fi

  if validate_ipv4 "${LAN_IPV4}"; then
    pass "LAN_IPV4 is valid: ${LAN_IPV4}"
  else
    fail "LAN_IPV4 is invalid: ${LAN_IPV4:-<empty>}"
  fi

  print -- "${LAN_CIDR}" | grep -Eq '^[0-9]+$' && [ "${LAN_CIDR}" -ge 1 ] && [ "${LAN_CIDR}" -le 32 ]     && pass "LAN_CIDR is valid: ${LAN_CIDR}"     || fail "LAN_CIDR is invalid: ${LAN_CIDR:-<empty>}"
}

check_commands() {
  for cmd in uname awk grep sed stat df swapctl ifconfig; do
    if command_exists "${cmd}"; then
      pass "required command present: ${cmd}"
    else
      fail "required command missing: ${cmd}"
    fi
  done
}

check_openbsd_version() {
  _os="$(uname -s 2>/dev/null || true)"
  _version="$(uname -r 2>/dev/null || true)"

  if [ "${_os}" = "OpenBSD" ]; then
    pass "operating system is OpenBSD"
  else
    fail "operating system is not OpenBSD, detected ${_os:-unknown}"
  fi

  if [ "${_version}" = "${OPENBSD_VERSION}" ]; then
    pass "OpenBSD version matches expected ${OPENBSD_VERSION}"
  else
    fail "OpenBSD version mismatch, expected ${OPENBSD_VERSION}, detected ${_version:-unknown}"
  fi
}

check_filesystem() {
  mounts="$(df -k 2>/dev/null | awk 'NR>1 {print $NF}' | sort -u)"

  if print -- "${mounts}" | grep -qx "/"; then
    pass "root filesystem mount / is present"
  else
    fail "root filesystem mount / is missing"
  fi

  for dir in /tmp /var /usr /usr/local /home; do
    if [ -d "${dir}" ]; then
      pass "directory present: ${dir}"
    else
      fail "directory missing: ${dir}"
    fi
  done

  tmp_mode="$(stat -f '%#p' /tmp 2>/dev/null || true)"
  if print -- "${tmp_mode}" | grep -Eq '1777$'; then
    pass "/tmp permissions end in 1777"
  else
    fail "/tmp permissions do not end in 1777, got ${tmp_mode:-<empty>}"
  fi

  if swapctl -l 2>/dev/null | awk 'NR==1{next} {print $1}' | grep -q .; then
    pass "swap device is configured"
  else
    fail "no swap device configured"
  fi
}

check_interfaces() {
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

  if [ "${ENABLE_WIREGUARD}" = "yes" ]; then
    if ifconfig "${WIREGUARD_INTERFACE}" >/dev/null 2>&1; then
      warn "WireGuard interface already exists: ${WIREGUARD_INTERFACE}"
    else
      pass "WireGuard interface not yet configured, this is acceptable before the WireGuard phase: ${WIREGUARD_INTERFACE}"
    fi
  fi
}

check_config_files() {
  for file in     "${PROJECT_ROOT}/config/system.conf"     "${PROJECT_ROOT}/config/network.conf"     "${PROJECT_ROOT}/config/domains.conf"
  do
    if [ -f "${file}" ]; then
      pass "config file present: ${file}"
    else
      warn "config file not present yet: ${file}"
    fi
  done
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
  print_phase_header "PHASE-00" "foundation verification"
  collect_inputs
  validate_inputs
  check_commands
  check_openbsd_version
  check_filesystem
  check_interfaces
  check_config_files
  print_result
}

main "$@"
