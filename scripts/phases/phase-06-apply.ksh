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
NGINX_DIR="${PROJECT_ROOT}/services/nginx"
POSTFIX_DIR="${PROJECT_ROOT}/services/postfix"
DOVECOT_DIR="${PROJECT_ROOT}/services/dovecot"

NGINX_TLS_FRAGMENT="${NGINX_DIR}/tls-server.fragment.example.generated"
NGINX_ACME_EXAMPLE="${NGINX_DIR}/acme-client.example.generated"
POSTFIX_TLS_FRAGMENT="${POSTFIX_DIR}/tls-main.cf.fragment.example.generated"
DOVECOT_TLS_FRAGMENT="${DOVECOT_DIR}/tls.conf.fragment.example.generated"
TLS_SUMMARY="${NGINX_DIR}/tls-summary.txt"

SAVE_CONFIG="${SAVE_CONFIG:-no}"

collect_inputs() {
  load_project_config

  prompt_value "MAIL_HOSTNAME" "Enter the public mail hostname, example mail.example.com"
  prompt_value "PRIMARY_DOMAIN" "Enter the primary administrative domain, example example.com"
  prompt_value "ADMIN_EMAIL" "Enter the administrator email address, example ops@example.com"
  prompt_value "TLS_CERT_MODE" "Enter the TLS certificate mode" "${TLS_CERT_MODE:-single_hostname}"
  prompt_value "TLS_ACME_PROVIDER" "Enter the ACME provider tool" "${TLS_ACME_PROVIDER:-acme-client}"
  prompt_value "TLS_CERT_FQDN" "Enter the certificate FQDN" "${TLS_CERT_FQDN:-${MAIL_HOSTNAME}}"
  prompt_value "TLS_CERT_PATH_FULLCHAIN" "Enter the full chain certificate path" "${TLS_CERT_PATH_FULLCHAIN:-/etc/ssl/${MAIL_HOSTNAME}.fullchain.pem}"
  prompt_value "TLS_CERT_PATH_KEY" "Enter the private key path" "${TLS_CERT_PATH_KEY:-/etc/ssl/private/${MAIL_HOSTNAME}.key}"
}

validate_inputs() {
  validate_hostname "${MAIL_HOSTNAME}" || die "invalid MAIL_HOSTNAME: ${MAIL_HOSTNAME}"
  validate_domain "${PRIMARY_DOMAIN}" || die "invalid PRIMARY_DOMAIN: ${PRIMARY_DOMAIN}"
  validate_email "${ADMIN_EMAIL}" || die "invalid ADMIN_EMAIL: ${ADMIN_EMAIL}"
  [ "${TLS_CERT_MODE}" = "single_hostname" ] || die "TLS_CERT_MODE must be single_hostname for the public baseline"
  [ "${TLS_ACME_PROVIDER}" = "acme-client" ] || die "TLS_ACME_PROVIDER must be acme-client for the public baseline"
  validate_hostname "${TLS_CERT_FQDN}" || die "invalid TLS_CERT_FQDN: ${TLS_CERT_FQDN}"
  [ "${TLS_CERT_FQDN}" = "${MAIL_HOSTNAME}" ] || die "TLS_CERT_FQDN must match MAIL_HOSTNAME in the public baseline"
  validate_absolute_path "${TLS_CERT_PATH_FULLCHAIN}" || die "invalid TLS_CERT_PATH_FULLCHAIN: ${TLS_CERT_PATH_FULLCHAIN}"
  validate_absolute_path "${TLS_CERT_PATH_KEY}" || die "invalid TLS_CERT_PATH_KEY: ${TLS_CERT_PATH_KEY}"
}

save_configs_if_requested() {
  [ "${SAVE_CONFIG}" = "yes" ] || return 0

  write_kv_config "${SYSTEM_CONF}"     "OPENBSD_VERSION="${OPENBSD_VERSION:-7.8}""     "MAIL_HOSTNAME="${MAIL_HOSTNAME}""     "PRIMARY_DOMAIN="${PRIMARY_DOMAIN}""     "ADMIN_EMAIL="${ADMIN_EMAIL}""     "PUBLIC_IPV4="${PUBLIC_IPV4:-203.0.113.10}""     "TIMEZONE="${TIMEZONE:-UTC}""     "TLS_CERT_MODE="${TLS_CERT_MODE}""     "TLS_ACME_PROVIDER="${TLS_ACME_PROVIDER}""     "TLS_CERT_FQDN="${TLS_CERT_FQDN}""     "TLS_CERT_PATH_FULLCHAIN="${TLS_CERT_PATH_FULLCHAIN}""     "TLS_CERT_PATH_KEY="${TLS_CERT_PATH_KEY}""
}

check_commands() {
  require_command mkdir
  require_command cat
  require_command grep
  require_command awk
  require_command acme-client
  require_command openssl
}

generate_files() {
  mkdir -p "${NGINX_DIR}" "${POSTFIX_DIR}" "${DOVECOT_DIR}"

  cat > "${NGINX_TLS_FRAGMENT}" <<EOF
ssl_certificate ${TLS_CERT_PATH_FULLCHAIN};
ssl_certificate_key ${TLS_CERT_PATH_KEY};
server_name ${MAIL_HOSTNAME};
EOF

  cat > "${POSTFIX_TLS_FRAGMENT}" <<EOF
smtpd_tls_cert_file = ${TLS_CERT_PATH_FULLCHAIN}
smtpd_tls_key_file = ${TLS_CERT_PATH_KEY}
smtp_tls_security_level = may
smtpd_tls_security_level = may
EOF

  cat > "${DOVECOT_TLS_FRAGMENT}" <<EOF
ssl = required
ssl_cert = <${TLS_CERT_PATH_FULLCHAIN}
ssl_key = <${TLS_CERT_PATH_KEY}
EOF

  cat > "${NGINX_ACME_EXAMPLE}" <<EOF
domain ${TLS_CERT_FQDN} {
        alternative names { }
        domain key "/etc/ssl/private/${TLS_CERT_FQDN}.key"
        domain full chain certificate "/etc/ssl/${TLS_CERT_FQDN}.fullchain.pem"
        sign with letsencrypt
}
EOF

  cat > "${TLS_SUMMARY}" <<EOF
Phase 06 TLS summary
MAIL_HOSTNAME: ${MAIL_HOSTNAME}
PRIMARY_DOMAIN: ${PRIMARY_DOMAIN}
ADMIN_EMAIL: ${ADMIN_EMAIL}
TLS_CERT_MODE: ${TLS_CERT_MODE}
TLS_ACME_PROVIDER: ${TLS_ACME_PROVIDER}
TLS_CERT_FQDN: ${TLS_CERT_FQDN}
TLS_CERT_PATH_FULLCHAIN: ${TLS_CERT_PATH_FULLCHAIN}
TLS_CERT_PATH_KEY: ${TLS_CERT_PATH_KEY}
EOF
}

main() {
  print_phase_header "PHASE-06" "tls and certificate automation"
  collect_inputs
  validate_inputs
  save_configs_if_requested
  check_commands
  generate_files
  log_info "phase 06 tls and certificate automation completed successfully"
  log_info "next step: run ./scripts/phases/phase-06-verify.ksh"
}

main "$@"
