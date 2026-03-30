#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
[ -f "${COMMON_LIB}" ] || { print -- "ERROR missing shared library: ${COMMON_LIB}" >&2; exit 1; }
. "${COMMON_LIB}"

OUTPUT_ROOT="$(core_runtime_render_root)"
EXAMPLE_ROOT="$(core_runtime_example_root)"

usage() {
  cat <<EOF
usage: $0 [--output-root /path]
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --output-root)
        [ $# -ge 2 ] || die "missing value for --output-root"
        OUTPUT_ROOT="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        die "unknown argument: $1"
        ;;
    esac
  done
}

validate_output_root() {
  case "${OUTPUT_ROOT}" in
    "${EXAMPLE_ROOT}"|${EXAMPLE_ROOT}/*)
      die "refusing to render live operator output into tracked sanitized example tree: ${EXAMPLE_ROOT}"
      ;;
  esac
}

split_host_port() {
  _value="$1"
  _host="${_value%:*}"
  _port="${_value##*:}"
  print -- "${_host} ${_port}"
}

load_and_validate() {
  load_project_config
  prompt_value "MAIL_HOSTNAME" "Enter the public mail hostname" "mail.example.com"
  prompt_value "PRIMARY_DOMAIN" "Enter the primary mail domain" "example.com"
  prompt_value "ADMIN_EMAIL" "Enter the administrative email" "ops@${PRIMARY_DOMAIN}"
  prompt_value "DOMAIN_ADMIN_EMAIL" "Enter the domain administration email" "${ADMIN_EMAIL}"
  prompt_value "POSTMASTER_EMAIL" "Enter the postmaster email" "postmaster@${PRIMARY_DOMAIN}"
  prompt_value "ABUSE_EMAIL" "Enter the abuse email" "abuse@${PRIMARY_DOMAIN}"
  prompt_value "HOSTMASTER_EMAIL" "Enter the hostmaster email" "hostmaster@${PRIMARY_DOMAIN}"
  prompt_value "WEBMASTER_EMAIL" "Enter the webmaster email" "webmaster@${PRIMARY_DOMAIN}"
  prompt_value "TLS_CERT_PATH_FULLCHAIN" "Enter the fullchain certificate path" "/etc/ssl/${MAIL_HOSTNAME}.fullchain.pem"
  prompt_value "TLS_CERT_PATH_KEY" "Enter the key path" "/etc/ssl/private/${MAIL_HOSTNAME}.key"
  prompt_value "WIREGUARD_SUBNET" "Enter the WireGuard subnet" "10.44.0.0/24"
  prompt_value "WIREGUARD_BIND_IPV4" "Enter the WireGuard IPv4 bind address" "10.44.0.1"
  prompt_value "LAN_SUBNET" "Enter the LAN subnet" "192.168.1.0/24"
  prompt_value "NGINX_HTTPS_BINDS" "Enter the nginx https binds separated by spaces" "127.0.0.1:443 ${WIREGUARD_BIND_IPV4}:443"
  prompt_value "POSTFIX_SUBMISSION_LOOPBACK_BIND" "Enter the loopback submission bind" "127.0.0.1:587"
  prompt_value "POSTFIX_SUBMISSION_VPN_BIND" "Enter the VPN submission bind" "${WIREGUARD_BIND_IPV4}:587"
  prompt_value "POSTFIX_SMTPS_LOOPBACK_BIND" "Enter the loopback smtps bind" "127.0.0.1:465"
  prompt_value "POSTFIX_SMTPS_VPN_BIND" "Enter the VPN smtps bind" "${WIREGUARD_BIND_IPV4}:465"
  prompt_value "POSTFIX_MYNETWORKS" "Enter trusted networks separated by spaces" "127.0.0.0/8 ${WIREGUARD_SUBNET} ${LAN_SUBNET}"
  prompt_value "POSTFIX_VMAIL_BASE" "Enter the virtual mail base path" "/var/vmail"
  prompt_value "POSTFIX_VMAIL_UID" "Enter the virtual mail UID" "2000"
  prompt_value "POSTFIX_VMAIL_GID" "Enter the virtual mail GID" "2000"
  prompt_value "POSTFIX_RELAYHOST" "Enter the outbound relayhost" "[smtp-relay.brevo.com]:587"
  prompt_value "POSTFIX_DB_NAME" "Enter the Postfix SQL database name" "${POSTFIX_DB_NAME:-postfixadmin}"
  prompt_value "POSTFIX_DB_USER" "Enter the Postfix SQL database user" "${POSTFIX_DB_USER:-postfixadmin}"
  prompt_value "POSTFIX_DB_PASSWORD" "Enter the Postfix SQL database password"
  prompt_value "POSTFIXADMIN_DB_NAME" "Enter the PostfixAdmin database name" "${POSTFIXADMIN_DB_NAME:-postfixadmin}"
  prompt_value "POSTFIXADMIN_DB_USER" "Enter the PostfixAdmin database user" "${POSTFIXADMIN_DB_USER:-postfixadmin}"
  prompt_value "POSTFIXADMIN_DB_PASSWORD" "Enter the PostfixAdmin database password"
  prompt_value "POSTFIXADMIN_SETUP_PASSWORD_HASH" "Enter the PostfixAdmin setup password hash"
  prompt_value "ROUNDCUBE_DB_NAME" "Enter the Roundcube database name" "${ROUNDCUBE_DB_NAME:-roundcube}"
  prompt_value "ROUNDCUBE_DB_USER" "Enter the Roundcube database user" "${ROUNDCUBE_DB_USER:-roundcube}"
  prompt_value "ROUNDCUBE_DB_PASSWORD" "Enter the Roundcube database password"
  prompt_value "ROUNDCUBE_DES_KEY" "Enter the Roundcube DES key"
  prompt_value "DOVECOT_DB_NAME" "Enter the Dovecot database name" "${DOVECOT_DB_NAME:-postfixadmin}"
  prompt_value "DOVECOT_DB_USER" "Enter the Dovecot database user" "${DOVECOT_DB_USER:-postfixadmin}"
  prompt_value "DOVECOT_DB_PASSWORD" "Enter the Dovecot database password"
  prompt_value "DOVECOT_LISTEN" "Enter Dovecot listen addresses" "${WIREGUARD_BIND_IPV4} 127.0.0.1"
  prompt_value "DOVECOT_MAIL_LOCATION" "Enter the Dovecot mail location" "maildir:${POSTFIX_VMAIL_BASE}/%d/%n"
  prompt_value "DOVECOT_VMAIL_UID" "Enter the Dovecot vmail UID" "${POSTFIX_VMAIL_UID}"
  prompt_value "DOVECOT_VMAIL_GID" "Enter the Dovecot vmail GID" "${POSTFIX_VMAIL_GID}"
  prompt_value "DOVECOT_FIRST_VALID_UID" "Enter the first valid UID" "${POSTFIX_VMAIL_UID}"
  prompt_value "DOVECOT_LAST_VALID_UID" "Enter the last valid UID" "${POSTFIX_VMAIL_UID}"
  prompt_value "DOVECOT_AUTH_MECHANISMS" "Enter Dovecot auth mechanisms" "plain login"
  prompt_value "RSPAMD_MILTER_BIND" "Enter the Rspamd milter bind" "127.0.0.1:11332"
  prompt_value "RSPAMD_NORMAL_BIND" "Enter the Rspamd normal bind" "127.0.0.1:11333"
  prompt_value "RSPAMD_CONTROLLER_BIND" "Enter the Rspamd controller bind" "${WIREGUARD_BIND_IPV4}:11334"
  prompt_value "RSPAMD_CONTROLLER_SECURE_IP" "Enter the Rspamd controller secure network" "${WIREGUARD_SUBNET}"
  prompt_value "RSPAMD_REDIS_HOST" "Enter the Redis host" "127.0.0.1"
  prompt_value "RSPAMD_REDIS_PORT" "Enter the Redis port" "6379"
  prompt_value "RSPAMD_CLAMAV_SOCKET" "Enter the ClamAV socket path" "/var/run/clamav/clamd.sock"
  prompt_value "RSPAMD_CONTROLLER_PASSWORD_HASH" "Enter the Rspamd controller password hash"
  prompt_value "DKIM_SELECTOR" "Enter the DKIM selector" "mail"
  prompt_value "BREVO_SMTP_LOGIN" "Enter the Brevo SMTP login"
  prompt_value "BREVO_SMTP_PASSWORD" "Enter the Brevo SMTP password"
  prompt_value "POSTFIXADMIN_WEB_HOSTNAME" "Enter the PostfixAdmin hostname" "${MAIL_HOSTNAME}"

  require_valid_hostname "MAIL_HOSTNAME"
  require_valid_domain "PRIMARY_DOMAIN"
  require_valid_email "ADMIN_EMAIL"
  require_valid_email "DOMAIN_ADMIN_EMAIL"
  require_valid_email "POSTMASTER_EMAIL"
  require_valid_email "ABUSE_EMAIL"
  require_valid_email "HOSTMASTER_EMAIL"
  require_valid_email "WEBMASTER_EMAIL"
  require_valid_password_value "POSTFIX_DB_PASSWORD"
  require_valid_password_value "POSTFIXADMIN_DB_PASSWORD"
  require_valid_password_value "ROUNDCUBE_DB_PASSWORD"
  require_valid_password_value "ROUNDCUBE_DES_KEY"
  require_valid_password_value "DOVECOT_DB_PASSWORD"
  require_valid_password_value "RSPAMD_CONTROLLER_PASSWORD_HASH"
  validate_host_port "${RSPAMD_MILTER_BIND}" || die "invalid RSPAMD_MILTER_BIND: ${RSPAMD_MILTER_BIND}"
  validate_host_port "${RSPAMD_NORMAL_BIND}" || die "invalid RSPAMD_NORMAL_BIND: ${RSPAMD_NORMAL_BIND}"
  validate_host_port "${RSPAMD_CONTROLLER_BIND}" || die "invalid RSPAMD_CONTROLLER_BIND: ${RSPAMD_CONTROLLER_BIND}"
  validate_cidr_network "${WIREGUARD_SUBNET}" || die "invalid WIREGUARD_SUBNET: ${WIREGUARD_SUBNET}"

  set -- $(split_host_port "${RSPAMD_MILTER_BIND}")
  RSPAMD_MILTER_PORT="$2"
  set -- ${NGINX_HTTPS_BINDS}
  NGINX_HTTPS_BIND_1="${1:-127.0.0.1:443}"
  NGINX_HTTPS_BIND_2="${2:-${WIREGUARD_BIND_IPV4}:443}"
}

render_core() {
  rm -rf "${OUTPUT_ROOT}"
  ensure_directory "${OUTPUT_ROOT}"

  render_template_file "${PROJECT_ROOT}/services/mariadb/etc/my.cnf.template" "${OUTPUT_ROOT}/etc/my.cnf"

  render_template_file "${PROJECT_ROOT}/services/postfix/etc/postfix/main.cf.template" "${OUTPUT_ROOT}/etc/postfix/main.cf"     "MAIL_HOSTNAME=${MAIL_HOSTNAME}" "PRIMARY_DOMAIN=${PRIMARY_DOMAIN}" "POSTFIX_MYNETWORKS=${POSTFIX_MYNETWORKS}"     "POSTFIX_VMAIL_UID=${POSTFIX_VMAIL_UID}" "POSTFIX_VMAIL_GID=${POSTFIX_VMAIL_GID}" "POSTFIX_VMAIL_BASE=${POSTFIX_VMAIL_BASE}"     "TLS_CERT_PATH_FULLCHAIN=${TLS_CERT_PATH_FULLCHAIN}" "TLS_CERT_PATH_KEY=${TLS_CERT_PATH_KEY}"     "POSTFIX_RELAYHOST=${POSTFIX_RELAYHOST}" "RSPAMD_MILTER_PORT=${RSPAMD_MILTER_PORT}"
  render_template_file "${PROJECT_ROOT}/services/postfix/etc/postfix/master.cf.template" "${OUTPUT_ROOT}/etc/postfix/master.cf"     "POSTFIX_SUBMISSION_LOOPBACK_BIND=${POSTFIX_SUBMISSION_LOOPBACK_BIND}" "POSTFIX_SUBMISSION_VPN_BIND=${POSTFIX_SUBMISSION_VPN_BIND}"     "POSTFIX_SMTPS_LOOPBACK_BIND=${POSTFIX_SMTPS_LOOPBACK_BIND}" "POSTFIX_SMTPS_VPN_BIND=${POSTFIX_SMTPS_VPN_BIND}"
  for _tmpl in mysql_virtual_domains_maps.cf mysql_virtual_mailbox_maps.cf mysql_virtual_alias_maps.cf mysql_virtual_alias_domain_maps.cf; do
    render_template_file "${PROJECT_ROOT}/services/postfix/etc/postfix/${_tmpl}.template" "${OUTPUT_ROOT}/etc/postfix/${_tmpl}"       "POSTFIX_DB_NAME=${POSTFIX_DB_NAME}" "POSTFIX_DB_USER=${POSTFIX_DB_USER}" "POSTFIX_DB_PASSWORD=${POSTFIX_DB_PASSWORD}"
  done
  render_template_file "${PROJECT_ROOT}/services/postfix/etc/postfix/postscreen_access.cidr.template" "${OUTPUT_ROOT}/etc/postfix/postscreen_access.cidr"     "WIREGUARD_SUBNET=${WIREGUARD_SUBNET}" "LAN_SUBNET=${LAN_SUBNET}"
  cp "${PROJECT_ROOT}/services/postfix/etc/postfix/tls_policy.template" "${OUTPUT_ROOT}/etc/postfix/tls_policy"
  render_template_file "${PROJECT_ROOT}/services/postfix/etc/postfix/sasl_passwd.template" "${OUTPUT_ROOT}/etc/postfix/sasl_passwd"     "BREVO_SMTP_LOGIN=${BREVO_SMTP_LOGIN}" "BREVO_SMTP_PASSWORD=${BREVO_SMTP_PASSWORD}"
  build_postfix_hash_maps_in_tree "${OUTPUT_ROOT}" 0

  render_template_file "${PROJECT_ROOT}/services/dovecot/etc/dovecot/dovecot.conf.template" "${OUTPUT_ROOT}/etc/dovecot/dovecot.conf"     "DOVECOT_LISTEN=${DOVECOT_LISTEN}"
  render_template_file "${PROJECT_ROOT}/services/dovecot/etc/dovecot/local.conf.template" "${OUTPUT_ROOT}/etc/dovecot/local.conf"     "DOVECOT_MAIL_LOCATION=${DOVECOT_MAIL_LOCATION}" "DOVECOT_VMAIL_UID=${DOVECOT_VMAIL_UID}" "DOVECOT_VMAIL_GID=${DOVECOT_VMAIL_GID}"     "DOVECOT_FIRST_VALID_UID=${DOVECOT_FIRST_VALID_UID}" "DOVECOT_LAST_VALID_UID=${DOVECOT_LAST_VALID_UID}"     "TLS_CERT_PATH_FULLCHAIN=${TLS_CERT_PATH_FULLCHAIN}" "TLS_CERT_PATH_KEY=${TLS_CERT_PATH_KEY}"     "DOVECOT_AUTH_MECHANISMS=${DOVECOT_AUTH_MECHANISMS}" "POSTFIX_VMAIL_BASE=${POSTFIX_VMAIL_BASE}" "POSTMASTER_EMAIL=${POSTMASTER_EMAIL}"
  render_template_file "${PROJECT_ROOT}/services/dovecot/etc/dovecot/dovecot-sql.conf.ext.template" "${OUTPUT_ROOT}/etc/dovecot/dovecot-sql.conf.ext"     "DOVECOT_DB_NAME=${DOVECOT_DB_NAME}" "DOVECOT_DB_USER=${DOVECOT_DB_USER}" "DOVECOT_DB_PASSWORD=${DOVECOT_DB_PASSWORD}"
  copy_tree_contents "${PROJECT_ROOT}/services/dovecot/etc/dovecot/conf.d" "${OUTPUT_ROOT}/etc/dovecot/conf.d"
  copy_tree_contents "${PROJECT_ROOT}/services/dovecot/etc/dovecot/sieve-before" "${OUTPUT_ROOT}/etc/dovecot/sieve-before"

  copy_tree_contents "${PROJECT_ROOT}/services/nginx/etc/nginx/conf-available" "${OUTPUT_ROOT}/etc/nginx/conf-available"
  copy_tree_contents "${PROJECT_ROOT}/services/nginx/etc/nginx/templates" "${OUTPUT_ROOT}/etc/nginx/templates"
  render_template_file "${PROJECT_ROOT}/services/nginx/etc/nginx/templates/rspamd.tmpl.template" "${OUTPUT_ROOT}/etc/nginx/templates/rspamd.tmpl"     "RSPAMD_CONTROLLER_BIND=${RSPAMD_CONTROLLER_BIND}" "WIREGUARD_SUBNET=${WIREGUARD_SUBNET}"
  render_template_file "${PROJECT_ROOT}/services/nginx/etc/nginx/templates/ssl.tmpl.template" "${OUTPUT_ROOT}/etc/nginx/templates/ssl.tmpl"     "TLS_CERT_PATH_FULLCHAIN=${TLS_CERT_PATH_FULLCHAIN}" "TLS_CERT_PATH_KEY=${TLS_CERT_PATH_KEY}"
  render_template_file "${PROJECT_ROOT}/services/nginx/etc/nginx/sites-available/main.conf.template" "${OUTPUT_ROOT}/etc/nginx/sites-available/main.conf"
  render_template_file "${PROJECT_ROOT}/services/nginx/etc/nginx/sites-available/main-ssl.conf.template" "${OUTPUT_ROOT}/etc/nginx/sites-available/main-ssl.conf"     "NGINX_HTTPS_BIND_1=${NGINX_HTTPS_BIND_1}" "NGINX_HTTPS_BIND_2=${NGINX_HTTPS_BIND_2}" "MAIL_HOSTNAME=${MAIL_HOSTNAME}" "WIREGUARD_BIND_IPV4=${WIREGUARD_BIND_IPV4}"
  render_template_file "${PROJECT_ROOT}/services/nginx/etc/nginx/control-plane.allow.template" "${OUTPUT_ROOT}/etc/nginx/control-plane.allow"     "WIREGUARD_SUBNET=${WIREGUARD_SUBNET}"

  rm -f "${OUTPUT_ROOT}/etc/nginx/templates/rspamd.tmpl.template" "${OUTPUT_ROOT}/etc/nginx/templates/ssl.tmpl.template"

  render_template_file "${PROJECT_ROOT}/services/postfixadmin/var/www/postfixadmin/config.local.php.template" "${OUTPUT_ROOT}/var/www/postfixadmin/config.local.php"     "POSTFIXADMIN_DB_USER=${POSTFIXADMIN_DB_USER}" "POSTFIXADMIN_DB_PASSWORD=${POSTFIXADMIN_DB_PASSWORD}" "POSTFIXADMIN_DB_NAME=${POSTFIXADMIN_DB_NAME}"     "POSTFIXADMIN_SETUP_PASSWORD_HASH=${POSTFIXADMIN_SETUP_PASSWORD_HASH}" "ABUSE_EMAIL=${ABUSE_EMAIL}" "HOSTMASTER_EMAIL=${HOSTMASTER_EMAIL}"     "POSTMASTER_EMAIL=${POSTMASTER_EMAIL}" "WEBMASTER_EMAIL=${WEBMASTER_EMAIL}" "DOMAIN_ADMIN_EMAIL=${DOMAIN_ADMIN_EMAIL}"     "POSTFIXADMIN_WEB_HOSTNAME=${POSTFIXADMIN_WEB_HOSTNAME}"
  copy_tree_contents "${PROJECT_ROOT}/services/postfixadmin/etc/postfixadmin" "${OUTPUT_ROOT}/etc/postfixadmin"

  render_template_file "${PROJECT_ROOT}/services/roundcube/var/www/roundcubemail/config/config.inc.php.template" "${OUTPUT_ROOT}/var/www/roundcubemail/config/config.inc.php"     "ROUNDCUBE_DB_USER=${ROUNDCUBE_DB_USER}" "ROUNDCUBE_DB_PASSWORD=${ROUNDCUBE_DB_PASSWORD}" "ROUNDCUBE_DB_NAME=${ROUNDCUBE_DB_NAME}"     "MAIL_HOSTNAME=${MAIL_HOSTNAME}" "PRIMARY_DOMAIN=${PRIMARY_DOMAIN}" "ADMIN_EMAIL=${ADMIN_EMAIL}" "ROUNDCUBE_DES_KEY=${ROUNDCUBE_DES_KEY}"
  copy_tree_contents "${PROJECT_ROOT}/services/roundcube/etc/roundcube" "${OUTPUT_ROOT}/etc/roundcube"

  render_template_file "${PROJECT_ROOT}/services/rspamd/etc/rspamd/local.d/worker-controller.inc.template" "${OUTPUT_ROOT}/etc/rspamd/local.d/worker-controller.inc"     "RSPAMD_CONTROLLER_BIND=${RSPAMD_CONTROLLER_BIND}" "RSPAMD_CONTROLLER_SECURE_IP=${RSPAMD_CONTROLLER_SECURE_IP}" "RSPAMD_CONTROLLER_PASSWORD_HASH=${RSPAMD_CONTROLLER_PASSWORD_HASH}"
  render_template_file "${PROJECT_ROOT}/services/rspamd/etc/rspamd/local.d/worker-proxy.inc.template" "${OUTPUT_ROOT}/etc/rspamd/local.d/worker-proxy.inc"     "RSPAMD_MILTER_BIND=${RSPAMD_MILTER_BIND}" "RSPAMD_NORMAL_BIND=${RSPAMD_NORMAL_BIND}"
  render_template_file "${PROJECT_ROOT}/services/rspamd/etc/rspamd/local.d/redis.conf.template" "${OUTPUT_ROOT}/etc/rspamd/local.d/redis.conf"     "RSPAMD_REDIS_HOST=${RSPAMD_REDIS_HOST}" "RSPAMD_REDIS_PORT=${RSPAMD_REDIS_PORT}"
  render_template_file "${PROJECT_ROOT}/services/rspamd/etc/rspamd/local.d/antivirus.conf.template" "${OUTPUT_ROOT}/etc/rspamd/local.d/antivirus.conf"     "RSPAMD_CLAMAV_SOCKET=${RSPAMD_CLAMAV_SOCKET}"
  render_template_file "${PROJECT_ROOT}/services/rspamd/etc/rspamd/local.d/dkim_signing.conf.template" "${OUTPUT_ROOT}/etc/rspamd/local.d/dkim_signing.conf"     "DKIM_SELECTOR=${DKIM_SELECTOR}" "WIREGUARD_SUBNET=${WIREGUARD_SUBNET}"
  copy_tree_contents "${PROJECT_ROOT}/services/rspamd/etc/rspamd/virustotal" "${OUTPUT_ROOT}/etc/rspamd/virustotal"

  cp "${PROJECT_ROOT}/services/redis/etc/redis.conf.template" "${OUTPUT_ROOT}/etc/redis.conf"
  cp "${PROJECT_ROOT}/services/clamd/etc/clamd.conf.template" "${OUTPUT_ROOT}/etc/clamd.conf"
  cp "${PROJECT_ROOT}/services/freshclam/etc/freshclam.conf.template" "${OUTPUT_ROOT}/etc/freshclam.conf"

  OUTPUT_PARENT="$(dirname "${OUTPUT_ROOT}")"
  ensure_directory "${OUTPUT_PARENT}"
  cat > "${OUTPUT_PARENT}/README.txt" <<EOF
This directory contains live operator-rendered runtime output.
It may contain real secrets and must remain local to the operator checkout.
Tracked sanitized examples remain under ${EXAMPLE_ROOT}.
EOF
  cat > "${OUTPUT_PARENT}/core-runtime-summary.txt" <<EOF
Rendered live core runtime rootfs
MAIL_HOSTNAME=${MAIL_HOSTNAME}
PRIMARY_DOMAIN=${PRIMARY_DOMAIN}
WIREGUARD_SUBNET=${WIREGUARD_SUBNET}
RSPAMD_CONTROLLER_BIND=${RSPAMD_CONTROLLER_BIND}
OUTPUT_ROOT=${OUTPUT_ROOT}
EOF
  log_info "rendered live core runtime config set into ${OUTPUT_ROOT}"
}

main() {
  parse_args "$@"
  validate_output_root
  load_and_validate
  render_core
}

main "$@"
