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
DOMAINS_CONF="${PROJECT_ROOT}/config/domains.conf"
DNS_DIR="${PROJECT_ROOT}/services/dns"
DKIM_DIR="${PROJECT_ROOT}/services/dkim"

ZONE_RECORDS="${DNS_DIR}/zone-records.example.generated"
MTA_STS_NOTES="${DNS_DIR}/mta-sts-notes.example.generated"
IDENTITY_SUMMARY="${DNS_DIR}/identity-summary.txt"
DKIM_RECORDS="${DKIM_DIR}/dkim-records.example.generated"

SAVE_CONFIG="${SAVE_CONFIG:-no}"

collect_inputs() {
  load_project_config
  prompt_value "MAIL_HOSTNAME" "Enter the public mail hostname, example mail.example.com"
  prompt_value "PRIMARY_DOMAIN" "Enter the primary administrative domain, example example.com"
  prompt_value "DOMAINS" "Enter all hosted mail domains separated by spaces, example 'example.com example.net'" "${PRIMARY_DOMAIN}"
  prompt_value "DKIM_SELECTOR" "Enter the DKIM selector" "${DKIM_SELECTOR:-mail}"
  prompt_value "SPF_POLICY" "Enter the SPF policy text" "${SPF_POLICY:-v=spf1 mx a:${MAIL_HOSTNAME} -all}"
  prompt_value "DMARC_POLICY" "Enter the DMARC policy text" "${DMARC_POLICY:-v=DMARC1; p=quarantine; rua=mailto:dmarc@${PRIMARY_DOMAIN}}"
  prompt_value "MX_PRIORITY" "Enter the MX priority" "${MX_PRIORITY:-10}"
  prompt_value "MTA_STS_MODE" "Enter the MTA-STS mode" "${MTA_STS_MODE:-testing}"
}

validate_inputs() {
  validate_hostname "${MAIL_HOSTNAME}" || die "invalid MAIL_HOSTNAME: ${MAIL_HOSTNAME}"
  validate_domain "${PRIMARY_DOMAIN}" || die "invalid PRIMARY_DOMAIN: ${PRIMARY_DOMAIN}"
  validate_space_separated_domains "${DOMAINS}" || die "DOMAINS must contain one or more valid domains"
  validate_selector "${DKIM_SELECTOR}" || die "invalid DKIM_SELECTOR: ${DKIM_SELECTOR}"
  validate_dns_text "${SPF_POLICY}" || die "SPF_POLICY must not be empty"
  validate_dns_text "${DMARC_POLICY}" || die "DMARC_POLICY must not be empty"
  validate_numeric "${MX_PRIORITY}" || die "invalid MX_PRIORITY: ${MX_PRIORITY}"
  validate_selector "${MTA_STS_MODE}" || die "invalid MTA_STS_MODE: ${MTA_STS_MODE}"
  print -- " ${DOMAINS} " | grep -q " ${PRIMARY_DOMAIN} " || die "PRIMARY_DOMAIN must also appear in DOMAINS"
}

save_configs_if_requested() {
  [ "${SAVE_CONFIG}" = "yes" ] || return 0
  write_kv_config "${DOMAINS_CONF}"     "PRIMARY_DOMAIN="${PRIMARY_DOMAIN}""     "DOMAINS="${DOMAINS}""     "INITIAL_MAILBOXES="${INITIAL_MAILBOXES:-postmaster@${PRIMARY_DOMAIN} abuse@${PRIMARY_DOMAIN}}""     "DOMAIN_ADMIN_EMAIL="${DOMAIN_ADMIN_EMAIL:-ops@${PRIMARY_DOMAIN}}""     "POSTFIX_VIRTUAL_TRANSPORT="${POSTFIX_VIRTUAL_TRANSPORT:-dovecot}""     "DOVECOT_MAIL_LOCATION="${DOVECOT_MAIL_LOCATION:-maildir:/var/vmail/%d/%n}""     "VMAIL_UID="${VMAIL_UID:-2000}""     "VMAIL_GID="${VMAIL_GID:-2000}""     "DKIM_SELECTOR="${DKIM_SELECTOR}""     "SPF_POLICY="${SPF_POLICY}""     "DMARC_POLICY="${DMARC_POLICY}""     "MX_PRIORITY="${MX_PRIORITY}""     "MTA_STS_MODE="${MTA_STS_MODE}""
  write_kv_config "${SYSTEM_CONF}"     "OPENBSD_VERSION="${OPENBSD_VERSION:-7.8}""     "MAIL_HOSTNAME="${MAIL_HOSTNAME}""     "PRIMARY_DOMAIN="${PRIMARY_DOMAIN}""     "ADMIN_EMAIL="${ADMIN_EMAIL:-ops@${PRIMARY_DOMAIN}}""     "PUBLIC_IPV4="${PUBLIC_IPV4:-203.0.113.10}""     "TIMEZONE="${TIMEZONE:-UTC}""     "TLS_CERT_MODE="${TLS_CERT_MODE:-single_hostname}""     "TLS_ACME_PROVIDER="${TLS_ACME_PROVIDER:-acme-client}""     "TLS_CERT_FQDN="${TLS_CERT_FQDN:-${MAIL_HOSTNAME}}""     "TLS_CERT_PATH_FULLCHAIN="${TLS_CERT_PATH_FULLCHAIN:-/etc/ssl/${MAIL_HOSTNAME}.fullchain.pem}""     "TLS_CERT_PATH_KEY="${TLS_CERT_PATH_KEY:-/etc/ssl/private/${MAIL_HOSTNAME}.key}""     "ROUNDCUBE_ENABLED="${ROUNDCUBE_ENABLED:-yes}""     "ROUNDCUBE_WEB_HOSTNAME="${ROUNDCUBE_WEB_HOSTNAME:-${MAIL_HOSTNAME}}""     "POSTFIXADMIN_WEB_HOSTNAME="${POSTFIXADMIN_WEB_HOSTNAME:-${MAIL_HOSTNAME}}""     "RSPAMD_UI_HOSTNAME="${RSPAMD_UI_HOSTNAME:-${MAIL_HOSTNAME}}""
}

check_commands() {
  require_command mkdir
  require_command cat
  require_command grep
  require_command awk
}

generate_files() {
  mkdir -p "${DNS_DIR}" "${DKIM_DIR}"
  : > "${ZONE_RECORDS}"
  : > "${DKIM_RECORDS}"
  for domain in ${DOMAINS}; do
    cat >> "${ZONE_RECORDS}" <<EOF
; ${domain}
@                       IN MX ${MX_PRIORITY} ${MAIL_HOSTNAME}.
@                       IN TXT "${SPF_POLICY}"
_dmarc                  IN TXT "${DMARC_POLICY}"

EOF
    cat >> "${DKIM_RECORDS}" <<EOF
; ${domain}
${DKIM_SELECTOR}._domainkey.${domain}.    IN TXT "v=DKIM1; k=rsa; p=REPLACE_WITH_PUBLIC_KEY_FOR_${domain}"

EOF
  done
  cat > "${MTA_STS_NOTES}" <<EOF
MTA-STS notes
mode: ${MTA_STS_MODE}
policy host suggestion: mta-sts.${PRIMARY_DOMAIN}
policy id suggestion: 20260328
EOF
  cat > "${IDENTITY_SUMMARY}" <<EOF
Phase 09 identity summary
MAIL_HOSTNAME: ${MAIL_HOSTNAME}
PRIMARY_DOMAIN: ${PRIMARY_DOMAIN}
DOMAINS: ${DOMAINS}
DKIM_SELECTOR: ${DKIM_SELECTOR}
SPF_POLICY: ${SPF_POLICY}
DMARC_POLICY: ${DMARC_POLICY}
MX_PRIORITY: ${MX_PRIORITY}
MTA_STS_MODE: ${MTA_STS_MODE}
EOF
}

main() {
  print_phase_header "PHASE-09" "dns and identity publishing"
  collect_inputs
  validate_inputs
  save_configs_if_requested
  check_commands
  generate_files
  log_info "phase 09 dns and identity publishing completed successfully"
  log_info "next step: run ./scripts/phases/phase-09-verify.ksh"
}

main "$@"
