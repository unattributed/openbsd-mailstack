#!/bin/ksh
#
# scripts/phases/phase-00-apply.ksh
#
# Public Phase 00 apply script for openbsd-mailstack.
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
SECRETS_CONF="${PROJECT_ROOT}/config/secrets.conf"

SAVE_CONFIG="${SAVE_CONFIG:-}"
if [ -z "${SAVE_CONFIG}" ]; then
  SAVE_CONFIG="no"
fi

usage() {
  cat <<'EOF'
Usage:
  doas ./scripts/phases/phase-00-apply.ksh

Optional environment variables:
  OPENBSD_MAILSTACK_NONINTERACTIVE=1   Disable prompts, fail if required values are missing
  SAVE_CONFIG=yes                      Save prompted values into config/*.conf files
EOF
}

if [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

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
  [ -n "${_domain_list}" ] || die "DOMAINS must not be empty"

  _found_primary="no"
  for _domain in ${_domain_list}; do
    validate_domain "${_domain}" || die "invalid domain in DOMAINS: ${_domain}"
    if [ "${_domain}" = "${PRIMARY_DOMAIN}" ]; then
      _found_primary="yes"
    fi
  done

  [ "${_found_primary}" = "yes" ] || die "PRIMARY_DOMAIN must be present in DOMAINS"
}

validate_inputs() {
  require_valid_hostname "MAIL_HOSTNAME"
  require_valid_domain "PRIMARY_DOMAIN"
  require_valid_email "ADMIN_EMAIL"
  require_valid_ipv4 "PUBLIC_IPV4"
  require_valid_ipv4 "LAN_IPV4"
  validate_domain_list "${DOMAINS}"

  print -- "${LAN_CIDR}" | grep -Eq '^[0-9]+$' || die "LAN_CIDR must be numeric, got: ${LAN_CIDR}"
  [ "${LAN_CIDR}" -ge 1 ] && [ "${LAN_CIDR}" -le 32 ] || die "LAN_CIDR must be between 1 and 32, got: ${LAN_CIDR}"

  print -- "${LAN_INTERFACE}" | grep -Eq '^[a-zA-Z0-9._-]+$' || die "invalid LAN interface name: ${LAN_INTERFACE}"
  print -- "${WAN_INTERFACE}" | grep -Eq '^[a-zA-Z0-9._-]+$' || die "invalid WAN interface name: ${WAN_INTERFACE}"

  case "${ENABLE_WIREGUARD}" in
    yes|no) ;;
    *) die "ENABLE_WIREGUARD must be yes or no, got: ${ENABLE_WIREGUARD}" ;;
  esac

  if [ "${ENABLE_WIREGUARD}" = "yes" ]; then
    print -- "${WIREGUARD_INTERFACE:-}" | grep -Eq '^[a-zA-Z0-9._-]+$' || die "invalid WireGuard interface name: ${WIREGUARD_INTERFACE:-<empty>}"
    print -- "${WIREGUARD_SUBNET:-}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$' || die "invalid WireGuard subnet: ${WIREGUARD_SUBNET:-<empty>}"
  fi
}

save_configs_if_requested() {
  if [ "${SAVE_CONFIG}" != "yes" ]; then
    if is_noninteractive; then
      return 0
    fi
    confirm_yes_no "SAVE_CONFIG" "Save the collected values into config files for reuse" "yes"
  fi

  [ "${SAVE_CONFIG}" = "yes" ] || return 0

  log_info "writing ${SYSTEM_CONF}"
  write_kv_config "${SYSTEM_CONF}"     "OPENBSD_VERSION=\"${OPENBSD_VERSION}\""     "MAIL_HOSTNAME=\"${MAIL_HOSTNAME}\""     "PRIMARY_DOMAIN=\"${PRIMARY_DOMAIN}\""     "ADMIN_EMAIL=\"${ADMIN_EMAIL}\""     "PUBLIC_IPV4=\"${PUBLIC_IPV4}\""     "TIMEZONE=\"${TIMEZONE:-UTC}\""

  log_info "writing ${NETWORK_CONF}"
  write_kv_config "${NETWORK_CONF}"     "LAN_INTERFACE=\"${LAN_INTERFACE}\""     "WAN_INTERFACE=\"${WAN_INTERFACE}\""     "LAN_IPV4=\"${LAN_IPV4}\""     "LAN_CIDR=\"${LAN_CIDR}\""     "ENABLE_WIREGUARD=\"${ENABLE_WIREGUARD}\""     "WIREGUARD_INTERFACE=\"${WIREGUARD_INTERFACE:-wg0}\""     "WIREGUARD_SUBNET=\"${WIREGUARD_SUBNET:-10.44.0.0/24}\""

  log_info "writing ${DOMAINS_CONF}"
  write_kv_config "${DOMAINS_CONF}"     "PRIMARY_DOMAIN=\"${PRIMARY_DOMAIN}\""     "DOMAINS=\"${DOMAINS}\""

  if [ ! -f "${SECRETS_CONF}" ]; then
    log_info "creating placeholder ${SECRETS_CONF}"
    write_kv_config "${SECRETS_CONF}"       "VULTR_API_KEY=\"\""       "BREVO_API_KEY=\"\""       "VIRUSTOTAL_API_KEY=\"\""       "MYSQL_ROOT_PASSWORD=\"\""       "POSTFIXADMIN_DB_PASSWORD=\"\""       "ROUNDCUBE_DB_PASSWORD=\"\""
  fi
}

check_commands() {
  require_command uname
  require_command awk
  require_command grep
  require_command sed
  require_command stat
  require_command df
  require_command swapctl
}

check_openbsd_baseline() {
  ensure_openbsd
  ensure_openbsd_version "${OPENBSD_VERSION}"
}

check_filesystem_baseline() {
  mounts="$(df -k 2>/dev/null | awk 'NR>1 {print $NF}' | sort -u)"

  print -- "${mounts}" | grep -qx "/" || die "root filesystem mount / is not present"

  for dir in /tmp /var /usr /usr/local /home; do
    [ -d "${dir}" ] || die "required directory missing: ${dir}"
  done

  tmp_mode="$(stat -f '%#p' /tmp 2>/dev/null || true)"
  print -- "${tmp_mode}" | grep -Eq '1777$' || die "/tmp permissions are not correct, expected mode ending in 1777, got ${tmp_mode:-<empty>}"

  swapctl -l 2>/dev/null | awk 'NR==1{next} {print $1}' | grep -q . || die "no swap devices configured"
}

print_summary() {
  print
  print -- "Phase 00 summary"
  print -- "  OpenBSD version : ${OPENBSD_VERSION}"
  print -- "  Mail hostname   : ${MAIL_HOSTNAME}"
  print -- "  Primary domain  : ${PRIMARY_DOMAIN}"
  print -- "  Hosted domains  : ${DOMAINS}"
  print -- "  Admin email     : ${ADMIN_EMAIL}"
  print -- "  Public IPv4     : ${PUBLIC_IPV4}"
  print -- "  LAN interface   : ${LAN_INTERFACE}"
  print -- "  WAN interface   : ${WAN_INTERFACE}"
  print -- "  LAN IPv4        : ${LAN_IPV4}/${LAN_CIDR}"
  print -- "  WireGuard       : ${ENABLE_WIREGUARD}"
  if [ "${ENABLE_WIREGUARD}" = "yes" ]; then
    print -- "  WG interface    : ${WIREGUARD_INTERFACE}"
    print -- "  WG subnet       : ${WIREGUARD_SUBNET}"
  fi
  print
}

main() {
  print_phase_header "PHASE-00" "foundation"
  collect_inputs
  validate_inputs
  save_configs_if_requested
  check_commands
  check_openbsd_baseline
  check_filesystem_baseline
  print_summary
  log_info "phase 00 foundation checks completed successfully"
  log_info "next step: run ./scripts/phases/phase-00-verify.ksh"
}

main "$@"
