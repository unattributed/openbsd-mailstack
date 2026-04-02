#!/bin/ksh
set -u

[ -n "${PROJECT_ROOT:-}" ] || PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
[ -n "${CONFIG_DIR:-}" ] || CONFIG_DIR="${PROJECT_ROOT}/config"

NETWORK_CONF="${CONFIG_DIR}/network.conf"
DNS_CONF="${CONFIG_DIR}/dns.conf"
DDNS_CONF="${CONFIG_DIR}/ddns.conf"
NETWORK_RENDER_ROOT_DEFAULT="${PROJECT_ROOT}/.work/network-exposure/rootfs"
NETWORK_EXAMPLE_ROOT="${PROJECT_ROOT}/services/generated/rootfs"
IDENTITY_RENDER_ROOT_DEFAULT="${PROJECT_ROOT}/.work/identity"

network_exposure_defaults() {
  : "${OPENBSD_VERSION:=7.8}"
  : "${MAIL_HOSTNAME:=mail.example.com}"
  : "${PRIMARY_DOMAIN:=example.com}"
  : "${DOMAINS:=example.com}"
  : "${LAN_INTERFACE:=em0}"
  : "${WAN_INTERFACE:=egress}"
  : "${LAN_IPV4:=192.168.1.44}"
  : "${LAN_CIDR:=24}"
  : "${ROUTER_LAN_IPV4:=192.168.1.1}"
  : "${PUBLIC_IPV4:=203.0.113.10}"
  : "${DMZ_MODE:=no}"
  : "${DMZ_TARGET_IPV4:=${LAN_IPV4}}"
  : "${ENABLE_HTTP:=yes}"
  : "${ENABLE_HTTPS:=yes}"
  : "${ENABLE_SMTP:=yes}"
  : "${ENABLE_SUBMISSION:=no}"
  : "${ENABLE_IMAPS:=no}"
  : "${ENABLE_PUBLIC_SSH:=no}"
  : "${PUBLIC_SSH_PORT:=22}"
  : "${PUBLIC_TCP_PORTS:=25 80 443}"
  : "${PUBLIC_UDP_PORTS:=51820}"
  : "${ADMIN_VPN_ONLY:=yes}"
  : "${WEB_VPN_ONLY:=yes}"
  : "${ENABLE_WIREGUARD:=yes}"
  : "${WIREGUARD_INTERFACE:=wg0}"
  : "${WIREGUARD_PORT:=51820}"
  : "${WIREGUARD_SUBNET:=10.44.0.0/24}"
  : "${WIREGUARD_SERVER_IPV4:=10.44.0.1}"
  : "${WIREGUARD_SERVER_NAME:=openbsd-mailstack}"
  : "${WIREGUARD_ALLOWED_IPS:=10.44.0.0/24}"
  : "${WIREGUARD_ADMIN_CLIENTS:=operator-laptop}"
  : "${DNS_PROVIDER:=vultr}"
  : "${UNBOUND_ENABLED:=yes}"
  : "${SPLIT_DNS_ENABLED:=yes}"
  : "${UNBOUND_LISTEN_ADDRESSES:=127.0.0.1 ${LAN_IPV4} ${WIREGUARD_SERVER_IPV4}}"
  : "${UNBOUND_ACCESS_CONTROL:=127.0.0.0/8 allow ${LAN_IPV4%.*}.0/24 allow ${WIREGUARD_SUBNET} allow}"
  : "${MX_PRIORITY:=10}"
  : "${SPF_POLICY:=v=spf1 mx a:${MAIL_HOSTNAME} -all}"
  : "${DMARC_POLICY:=v=DMARC1; p=quarantine; rua=mailto:dmarc@${PRIMARY_DOMAIN}}"
  : "${DKIM_SELECTOR:=mail}"
  : "${MTA_STS_MODE:=testing}"
  : "${DDNS_ENABLED:=yes}"
  : "${DDNS_PROVIDER:=vultr}"
  : "${DDNS_TARGET_IPV4:=${PUBLIC_IPV4}}"
  : "${DDNS_TTL:=300}"
  : "${DDNS_DOMAINS:=${PRIMARY_DOMAIN}}"
  : "${DDNS_HOST_LABELS:=mail}"
  : "${DDNS_DRY_RUN_DEFAULT:=yes}"
  : "${DDNS_API_URL:=https://api.vultr.com/v2}"
}

load_network_exposure_config() {
  load_project_config
  network_exposure_defaults
}

validate_network_exposure_inputs() {
  require_valid_hostname "MAIL_HOSTNAME"
  require_valid_domain "PRIMARY_DOMAIN"
  validate_space_separated_domains "${DOMAINS}" || die "DOMAINS must be valid domain names"
  require_valid_ipv4 "LAN_IPV4"
  require_valid_ipv4 "ROUTER_LAN_IPV4"
  require_valid_ipv4 "PUBLIC_IPV4"
  print -- "${LAN_CIDR}" | grep -Eq '^[0-9]+$' || die "LAN_CIDR must be numeric"
  [ "${LAN_CIDR}" -ge 1 ] && [ "${LAN_CIDR}" -le 32 ] || die "LAN_CIDR must be between 1 and 32"
  validate_interface_name "${LAN_INTERFACE}" || die "invalid LAN_INTERFACE"
  validate_interface_name "${WAN_INTERFACE}" || die "invalid WAN_INTERFACE"
  case "${DMZ_MODE}" in yes|no) ;; *) die "DMZ_MODE must be yes or no" ;; esac
  case "${ENABLE_WIREGUARD}" in yes|no) ;; *) die "ENABLE_WIREGUARD must be yes or no" ;; esac
  case "${ADMIN_VPN_ONLY}" in yes|no) ;; *) die "ADMIN_VPN_ONLY must be yes or no" ;; esac
  case "${WEB_VPN_ONLY}" in yes|no) ;; *) die "WEB_VPN_ONLY must be yes or no" ;; esac
  case "${DDNS_ENABLED}" in yes|no) ;; *) die "DDNS_ENABLED must be yes or no" ;; esac
  validate_port_list "${PUBLIC_TCP_PORTS}" || die "PUBLIC_TCP_PORTS must be a valid space-separated port list"
  validate_port_list "${PUBLIC_UDP_PORTS}" || die "PUBLIC_UDP_PORTS must be a valid space-separated port list"
  validate_port "${PUBLIC_SSH_PORT}" || die "PUBLIC_SSH_PORT must be a valid port"
  if [ "${ENABLE_WIREGUARD}" = "yes" ]; then
    validate_interface_name "${WIREGUARD_INTERFACE}" || die "invalid WIREGUARD_INTERFACE"
    validate_ipv4_cidr "${WIREGUARD_SUBNET}" || die "invalid WIREGUARD_SUBNET"
    require_valid_ipv4 "WIREGUARD_SERVER_IPV4"
    validate_port "${WIREGUARD_PORT}" || die "invalid WIREGUARD_PORT"
  fi
  validate_mode_word "${DNS_PROVIDER}" || die "invalid DNS_PROVIDER"
  validate_mode_word "${DDNS_PROVIDER}" || die "invalid DDNS_PROVIDER"
  validate_numeric "${MX_PRIORITY}" || die "invalid MX_PRIORITY"
  validate_selector "${DKIM_SELECTOR}" || die "invalid DKIM_SELECTOR"
  validate_dns_text "${SPF_POLICY}" || die "SPF_POLICY must not be empty"
  validate_dns_text "${DMARC_POLICY}" || die "DMARC_POLICY must not be empty"
  validate_selector "${MTA_STS_MODE}" || die "invalid MTA_STS_MODE"
  validate_numeric_port "${DDNS_TTL}" || die "DDNS_TTL must be numeric"
  validate_space_separated_domains "${DDNS_DOMAINS}" || die "DDNS_DOMAINS must be valid domains"
  print -- "${DDNS_HOST_LABELS}" | grep -Eq '^[A-Za-z0-9*_. -]+$' || die "DDNS_HOST_LABELS must be a space-separated list of labels"
}

save_network_exposure_configs() {
  write_named_config "${NETWORK_CONF}"     "LAN_INTERFACE" "${LAN_INTERFACE}"     "WAN_INTERFACE" "${WAN_INTERFACE}"     "LAN_IPV4" "${LAN_IPV4}"     "LAN_CIDR" "${LAN_CIDR}"     "ROUTER_LAN_IPV4" "${ROUTER_LAN_IPV4}"     "PUBLIC_IPV4" "${PUBLIC_IPV4}"     "DMZ_MODE" "${DMZ_MODE}"     "DMZ_TARGET_IPV4" "${DMZ_TARGET_IPV4}"     "ENABLE_HTTP" "${ENABLE_HTTP}"     "ENABLE_HTTPS" "${ENABLE_HTTPS}"     "ENABLE_SMTP" "${ENABLE_SMTP}"     "ENABLE_SUBMISSION" "${ENABLE_SUBMISSION}"     "ENABLE_IMAPS" "${ENABLE_IMAPS}"     "ENABLE_PUBLIC_SSH" "${ENABLE_PUBLIC_SSH}"     "PUBLIC_SSH_PORT" "${PUBLIC_SSH_PORT}"     "PUBLIC_TCP_PORTS" "$(normalize_space_list "${PUBLIC_TCP_PORTS}")"     "PUBLIC_UDP_PORTS" "$(normalize_space_list "${PUBLIC_UDP_PORTS}")"     "ADMIN_VPN_ONLY" "${ADMIN_VPN_ONLY}"     "WEB_VPN_ONLY" "${WEB_VPN_ONLY}"     "ENABLE_WIREGUARD" "${ENABLE_WIREGUARD}"     "WIREGUARD_INTERFACE" "${WIREGUARD_INTERFACE}"     "WIREGUARD_PORT" "${WIREGUARD_PORT}"     "WIREGUARD_SUBNET" "${WIREGUARD_SUBNET}"     "WIREGUARD_SERVER_IPV4" "${WIREGUARD_SERVER_IPV4}"     "WIREGUARD_SERVER_NAME" "${WIREGUARD_SERVER_NAME}"     "WIREGUARD_ALLOWED_IPS" "${WIREGUARD_ALLOWED_IPS}"     "WIREGUARD_ADMIN_CLIENTS" "${WIREGUARD_ADMIN_CLIENTS}"

  write_named_config "${DNS_CONF}"     "DNS_PROVIDER" "${DNS_PROVIDER}"     "UNBOUND_ENABLED" "${UNBOUND_ENABLED}"     "SPLIT_DNS_ENABLED" "${SPLIT_DNS_ENABLED}"     "UNBOUND_LISTEN_ADDRESSES" "${UNBOUND_LISTEN_ADDRESSES}"     "UNBOUND_ACCESS_CONTROL" "${UNBOUND_ACCESS_CONTROL}"     "MX_PRIORITY" "${MX_PRIORITY}"     "SPF_POLICY" "${SPF_POLICY}"     "DMARC_POLICY" "${DMARC_POLICY}"     "DKIM_SELECTOR" "${DKIM_SELECTOR}"     "MTA_STS_MODE" "${MTA_STS_MODE}"

  write_named_config "${DDNS_CONF}"     "DDNS_ENABLED" "${DDNS_ENABLED}"     "DDNS_PROVIDER" "${DDNS_PROVIDER}"     "DDNS_TARGET_IPV4" "${DDNS_TARGET_IPV4}"     "DDNS_TTL" "${DDNS_TTL}"     "DDNS_DOMAINS" "$(normalize_space_list "${DDNS_DOMAINS}")"     "DDNS_HOST_LABELS" "$(normalize_space_list "${DDNS_HOST_LABELS}")"     "DDNS_DRY_RUN_DEFAULT" "${DDNS_DRY_RUN_DEFAULT}"     "DDNS_API_URL" "${DDNS_API_URL}"
}

network_render_root() {
  if [ -n "${OUTPUT_ROOT:-}" ]; then
    print -- "${OUTPUT_ROOT}"
    return 0
  fi
  print -- "${OPENBSD_MAILSTACK_NETWORK_RENDER_ROOT:-${NETWORK_RENDER_ROOT_DEFAULT}}"
}

network_example_root() {
  print -- "${NETWORK_EXAMPLE_ROOT}"
}

identity_render_root() {
  print -- "${OPENBSD_MAILSTACK_IDENTITY_RENDER_ROOT:-${IDENTITY_RENDER_ROOT_DEFAULT}}"
}

render_pf_conf() {
  _root="$1"
  mkdir -p "${_root}/etc/pf.anchors" || die "failed creating PF output directory"
  cat > "${_root}/etc/pf.conf" <<EOF
# Generated by openbsd-mailstack/scripts/install/render-network-exposure-configs.ksh
wan_if = "${WAN_INTERFACE}"
lan_if = "${LAN_INTERFACE}"
wg_if = "${WIREGUARD_INTERFACE}"
table <admin_vpn> persist { ${WIREGUARD_SUBNET} }

set skip on lo
block return all
pass out quick inet from any to any keep state
antispoof quick for { lo ${LAN_INTERFACE} ${WIREGUARD_INTERFACE} }

anchor "openbsd-mailstack-selfhost"
load anchor "openbsd-mailstack-selfhost" from "/etc/pf.anchors/openbsd-mailstack-selfhost"
EOF

  cat > "${_root}/etc/pf.anchors/openbsd-mailstack-selfhost" <<EOF
# Generated mailstack PF anchor
pass in on ${WAN_INTERFACE} inet proto tcp from any to (${WAN_INTERFACE}) port 25 keep state
pass in on ${WAN_INTERFACE} inet proto tcp from any to (${WAN_INTERFACE}) port { 80 443 } keep state
pass in on ${WAN_INTERFACE} inet proto udp from any to (${WAN_INTERFACE}) port ${WIREGUARD_PORT} keep state
pass in on ${WIREGUARD_INTERFACE} inet from ${WIREGUARD_SUBNET} to any keep state
block in quick on ${WAN_INTERFACE} inet proto tcp from any to (${WAN_INTERFACE}) port { 465 587 993 }
EOF
}

render_wireguard_conf() {
  _root="$1"
  mkdir -p "${_root}/etc" || die "failed creating wireguard output directory"
  cat > "${_root}/etc/hostname.${WIREGUARD_INTERFACE}" <<EOF
# Generated WireGuard hostname file
inet ${WIREGUARD_SERVER_IPV4} ${WIREGUARD_SUBNET#*/} NONE
!/usr/local/bin/wg setconf ${WIREGUARD_INTERFACE} /etc/wireguard/${WIREGUARD_INTERFACE}.conf
up
EOF
}

render_unbound_conf() {
  _root="$1"
  mkdir -p "${_root}/var/unbound/etc/conf.d" || die "failed creating unbound output directory"
  cat > "${_root}/var/unbound/etc/unbound.conf" <<EOF
# Generated by openbsd-mailstack
server:
  username: "_unbound"
  directory: "/var/unbound"
  chroot: "/var/unbound"
  auto-trust-anchor-file: "/var/unbound/db/root.key"
  interface: 127.0.0.1
  interface: ${LAN_IPV4}
  interface: ${WIREGUARD_SERVER_IPV4}
  access-control: 127.0.0.0/8 allow
  access-control: ${LAN_IPV4%.*}.0/24 allow
  access-control: ${WIREGUARD_SUBNET} allow
  hide-identity: yes
  hide-version: yes
  qname-minimisation: yes
  harden-glue: yes
  prefetch: yes
  val-log-level: 1
  include: "/var/unbound/etc/conf.d/*.conf"
EOF

  cat > "${_root}/var/unbound/etc/conf.d/mailstack-zones.conf" <<EOF
# Generated split-DNS view for ${MAIL_HOSTNAME}
local-zone: "${PRIMARY_DOMAIN}." static
local-data: "${MAIL_HOSTNAME}. 300 IN A ${LAN_IPV4}"
EOF
}

render_ddns_assets() {
  _root="$1"
  mkdir -p "${_root}/usr/local/bin" "${_root}/etc/examples/openbsd-mailstack" || die "failed creating ddns output directory"
  cat > "${_root}/usr/local/bin/vultr_ddns_sync.py" <<'EOF'
#!/usr/bin/env python3
import json
import os
import sys

domains = os.environ.get("DDNS_DOMAINS", "").split()
labels = os.environ.get("DDNS_HOST_LABELS", "mail").split()
target_ipv4 = os.environ.get("DDNS_TARGET_IPV4", "")
ttl = os.environ.get("DDNS_TTL", "300")
plan = []
for domain in domains:
    for label in labels:
        name = domain if label in ("@", "") else f"{label}.{domain}"
        plan.append({"type": "A", "name": name, "content": target_ipv4, "ttl": ttl})
json.dump({"mode": "preview", "records": plan}, sys.stdout, indent=2)
sys.stdout.write("\n")
EOF
  chmod 755 "${_root}/usr/local/bin/vultr_ddns_sync.py" || die "failed setting execute bit on rendered ddns helper"

  cat > "${_root}/etc/examples/openbsd-mailstack/ddns.env" <<EOF
DDNS_ENABLED="${DDNS_ENABLED}"
DDNS_PROVIDER="${DDNS_PROVIDER}"
DDNS_TARGET_IPV4="${DDNS_TARGET_IPV4}"
DDNS_TTL="${DDNS_TTL}"
DDNS_DOMAINS="${DDNS_DOMAINS}"
DDNS_HOST_LABELS="${DDNS_HOST_LABELS}"
DDNS_API_URL="${DDNS_API_URL}"
EOF
}

render_network_exposure_tree() {
  _root="$1"
  rm -rf "${_root}"
  mkdir -p "${_root}" || die "failed creating render root ${_root}"
  render_pf_conf "${_root}"
  if [ "${ENABLE_WIREGUARD}" = "yes" ]; then
    render_wireguard_conf "${_root}"
  fi
  if [ "${UNBOUND_ENABLED}" = "yes" ]; then
    render_unbound_conf "${_root}"
  fi
  if [ "${DDNS_ENABLED}" = "yes" ] && [ "${DDNS_PROVIDER}" = "vultr" ]; then
    render_ddns_assets "${_root}"
  fi
}
