#!/bin/ksh
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

NGINX_DIR="${PROJECT_ROOT}/services/nginx"
ROUNDCUBE_DIR="${PROJECT_ROOT}/services/roundcube"
POSTFIXADMIN_DIR="${PROJECT_ROOT}/services/postfixadmin"
RSPAMD_DIR="${PROJECT_ROOT}/services/rspamd"

ROUND_FRAG="${NGINX_DIR}/roundcube-server.fragment.example.generated"
PFA_FRAG="${NGINX_DIR}/postfixadmin-server.fragment.example.generated"
RSPAMD_FRAG="${NGINX_DIR}/rspamd-ui-server.fragment.example.generated"
WEB_SUMMARY="${NGINX_DIR}/web-access-summary.txt"
ROUND_SUMMARY="${ROUNDCUBE_DIR}/roundcube-config-summary.txt"
PFA_SUMMARY="${POSTFIXADMIN_DIR}/postfixadmin-access-summary.txt"
RSPAMD_SUMMARY="${RSPAMD_DIR}/rspamd-ui-access-summary.txt"

SAVE_CONFIG="${SAVE_CONFIG:-no}"

collect_inputs() {
  load_project_config
  prompt_value "MAIL_HOSTNAME" "Enter the public mail hostname, example mail.example.com"
  prompt_value "PRIMARY_DOMAIN" "Enter the primary administrative domain, example example.com"
  prompt_value "ENABLE_WIREGUARD" "Enable WireGuard, yes or no" "${ENABLE_WIREGUARD:-yes}"
  prompt_value "WIREGUARD_INTERFACE" "Enter the WireGuard interface name" "${WIREGUARD_INTERFACE:-wg0}"
  prompt_value "WIREGUARD_SUBNET" "Enter the WireGuard subnet in CIDR notation" "${WIREGUARD_SUBNET:-10.44.0.0/24}"
  prompt_value "WEB_VPN_ONLY" "Restrict web surfaces to VPN only, yes or no" "${WEB_VPN_ONLY:-yes}"
  prompt_value "ROUNDCUBE_ENABLED" "Enable Roundcube, yes or no" "${ROUNDCUBE_ENABLED:-yes}"
  prompt_value "ROUNDCUBE_WEB_HOSTNAME" "Enter the Roundcube web hostname" "${ROUNDCUBE_WEB_HOSTNAME:-${MAIL_HOSTNAME}}"
  prompt_value "POSTFIXADMIN_WEB_HOSTNAME" "Enter the PostfixAdmin web hostname" "${POSTFIXADMIN_WEB_HOSTNAME:-${MAIL_HOSTNAME}}"
  prompt_value "RSPAMD_UI_HOSTNAME" "Enter the Rspamd UI hostname" "${RSPAMD_UI_HOSTNAME:-${MAIL_HOSTNAME}}"
  prompt_value "TLS_CERT_PATH_FULLCHAIN" "Enter the full chain certificate path" "${TLS_CERT_PATH_FULLCHAIN:-/etc/ssl/${MAIL_HOSTNAME}.fullchain.pem}"
  prompt_value "TLS_CERT_PATH_KEY" "Enter the private key path" "${TLS_CERT_PATH_KEY:-/etc/ssl/private/${MAIL_HOSTNAME}.key}"
}

validate_inputs() {
  validate_hostname "${MAIL_HOSTNAME}" || die "invalid MAIL_HOSTNAME: ${MAIL_HOSTNAME}"
  validate_domain "${PRIMARY_DOMAIN}" || die "invalid PRIMARY_DOMAIN: ${PRIMARY_DOMAIN}"
  validate_yes_no "${ENABLE_WIREGUARD}" || die "ENABLE_WIREGUARD must be yes or no"
  [ "${ENABLE_WIREGUARD}" = "yes" ] || die "ENABLE_WIREGUARD must be yes for the public MVP web access baseline"
  validate_interface_name "${WIREGUARD_INTERFACE}" || die "invalid WIREGUARD_INTERFACE: ${WIREGUARD_INTERFACE}"
  validate_cidr_network "${WIREGUARD_SUBNET}" || die "invalid WIREGUARD_SUBNET: ${WIREGUARD_SUBNET}"
  validate_yes_no "${WEB_VPN_ONLY}" || die "WEB_VPN_ONLY must be yes or no"
  [ "${WEB_VPN_ONLY}" = "yes" ] || die "WEB_VPN_ONLY must be yes for the public MVP web access baseline"
  validate_yes_no "${ROUNDCUBE_ENABLED}" || die "ROUNDCUBE_ENABLED must be yes or no"
  validate_hostname "${ROUNDCUBE_WEB_HOSTNAME}" || die "invalid ROUNDCUBE_WEB_HOSTNAME: ${ROUNDCUBE_WEB_HOSTNAME}"
  validate_hostname "${POSTFIXADMIN_WEB_HOSTNAME}" || die "invalid POSTFIXADMIN_WEB_HOSTNAME: ${POSTFIXADMIN_WEB_HOSTNAME}"
  validate_hostname "${RSPAMD_UI_HOSTNAME}" || die "invalid RSPAMD_UI_HOSTNAME: ${RSPAMD_UI_HOSTNAME}"
  validate_absolute_path "${TLS_CERT_PATH_FULLCHAIN}" || die "invalid TLS_CERT_PATH_FULLCHAIN: ${TLS_CERT_PATH_FULLCHAIN}"
  validate_absolute_path "${TLS_CERT_PATH_KEY}" || die "invalid TLS_CERT_PATH_KEY: ${TLS_CERT_PATH_KEY}"
}

save_configs_if_requested() {
  [ "${SAVE_CONFIG}" = "yes" ] || return 0
  write_kv_config "${NETWORK_CONF}"     "LAN_INTERFACE="${LAN_INTERFACE:-em0}""     "WAN_INTERFACE="${WAN_INTERFACE:-em1}""     "LAN_IPV4="${LAN_IPV4:-192.168.1.10}""     "LAN_CIDR="${LAN_CIDR:-24}""     "ENABLE_WIREGUARD="${ENABLE_WIREGUARD}""     "WIREGUARD_INTERFACE="${WIREGUARD_INTERFACE}""     "WIREGUARD_SUBNET="${WIREGUARD_SUBNET}""     "WEB_VPN_ONLY="${WEB_VPN_ONLY}""
  write_kv_config "${SYSTEM_CONF}"     "OPENBSD_VERSION="${OPENBSD_VERSION:-7.8}""     "MAIL_HOSTNAME="${MAIL_HOSTNAME}""     "PRIMARY_DOMAIN="${PRIMARY_DOMAIN}""     "ADMIN_EMAIL="${ADMIN_EMAIL:-ops@${PRIMARY_DOMAIN}}""     "PUBLIC_IPV4="${PUBLIC_IPV4:-203.0.113.10}""     "TIMEZONE="${TIMEZONE:-UTC}""     "TLS_CERT_MODE="${TLS_CERT_MODE:-single_hostname}""     "TLS_ACME_PROVIDER="${TLS_ACME_PROVIDER:-acme-client}""     "TLS_CERT_FQDN="${TLS_CERT_FQDN:-${MAIL_HOSTNAME}}""     "TLS_CERT_PATH_FULLCHAIN="${TLS_CERT_PATH_FULLCHAIN}""     "TLS_CERT_PATH_KEY="${TLS_CERT_PATH_KEY}""     "ROUNDCUBE_ENABLED="${ROUNDCUBE_ENABLED}""     "ROUNDCUBE_WEB_HOSTNAME="${ROUNDCUBE_WEB_HOSTNAME}""     "POSTFIXADMIN_WEB_HOSTNAME="${POSTFIXADMIN_WEB_HOSTNAME}""     "RSPAMD_UI_HOSTNAME="${RSPAMD_UI_HOSTNAME}""
}

check_commands() {
  require_command mkdir
  require_command cat
  require_command grep
  require_command awk
  require_command nginx
  require_command rcctl
}

generate_files() {
  mkdir -p "${NGINX_DIR}" "${ROUNDCUBE_DIR}" "${POSTFIXADMIN_DIR}" "${RSPAMD_DIR}"

  cat > "${ROUND_FRAG}" <<EOF
server {
    listen 443 ssl;
    server_name ${ROUNDCUBE_WEB_HOSTNAME};
    ssl_certificate ${TLS_CERT_PATH_FULLCHAIN};
    ssl_certificate_key ${TLS_CERT_PATH_KEY};

    allow ${WIREGUARD_SUBNET};
    deny all;
}
EOF

  cat > "${PFA_FRAG}" <<EOF
server {
    listen 443 ssl;
    server_name ${POSTFIXADMIN_WEB_HOSTNAME};
    ssl_certificate ${TLS_CERT_PATH_FULLCHAIN};
    ssl_certificate_key ${TLS_CERT_PATH_KEY};

    allow ${WIREGUARD_SUBNET};
    deny all;
}
EOF

  cat > "${RSPAMD_FRAG}" <<EOF
server {
    listen 443 ssl;
    server_name ${RSPAMD_UI_HOSTNAME};
    ssl_certificate ${TLS_CERT_PATH_FULLCHAIN};
    ssl_certificate_key ${TLS_CERT_PATH_KEY};

    allow ${WIREGUARD_SUBNET};
    deny all;
}
EOF

  cat > "${WEB_SUMMARY}" <<EOF
Phase 08 web access summary
MAIL_HOSTNAME: ${MAIL_HOSTNAME}
PRIMARY_DOMAIN: ${PRIMARY_DOMAIN}
ENABLE_WIREGUARD: ${ENABLE_WIREGUARD}
WIREGUARD_INTERFACE: ${WIREGUARD_INTERFACE}
WIREGUARD_SUBNET: ${WIREGUARD_SUBNET}
WEB_VPN_ONLY: ${WEB_VPN_ONLY}
ROUNDCUBE_ENABLED: ${ROUNDCUBE_ENABLED}
ROUNDCUBE_WEB_HOSTNAME: ${ROUNDCUBE_WEB_HOSTNAME}
POSTFIXADMIN_WEB_HOSTNAME: ${POSTFIXADMIN_WEB_HOSTNAME}
RSPAMD_UI_HOSTNAME: ${RSPAMD_UI_HOSTNAME}
EOF

  cat > "${ROUND_SUMMARY}" <<EOF
Roundcube MVP webmail remains VPN only via ${WIREGUARD_SUBNET}
EOF

  cat > "${PFA_SUMMARY}" <<EOF
PostfixAdmin remains VPN only via ${WIREGUARD_SUBNET}
EOF

  cat > "${RSPAMD_SUMMARY}" <<EOF
Rspamd UI remains VPN only via ${WIREGUARD_SUBNET}
EOF
}

main() {
  print_phase_header "PHASE-08" "webmail and administrative access"
  collect_inputs
  validate_inputs
  save_configs_if_requested
  check_commands
  generate_files
  log_info "phase 08 webmail and administrative access completed successfully"
  log_info "next step: run ./scripts/phases/phase-08-verify.ksh"
}

main "$@"
