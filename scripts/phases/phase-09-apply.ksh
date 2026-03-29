#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${PROJECT_ROOT}/scripts/lib/network-exposure.ksh"

DNS_DIR="${PROJECT_ROOT}/services/dns"
DKIM_DIR="${PROJECT_ROOT}/services/dkim"
SAVE_CONFIG="${SAVE_CONFIG:-no}"

ZONE_RECORDS="${DNS_DIR}/zone-records.example.generated"
MTA_STS_NOTES="${DNS_DIR}/mta-sts-notes.example.generated"
IDENTITY_SUMMARY="${DNS_DIR}/identity-summary.txt"
DKIM_RECORDS="${DKIM_DIR}/dkim-records.example.generated"

collect_inputs() {
  load_network_exposure_config
  prompt_value "MAIL_HOSTNAME" "Enter the public mail hostname" "${MAIL_HOSTNAME}"
  prompt_value "PRIMARY_DOMAIN" "Enter the primary domain" "${PRIMARY_DOMAIN}"
  prompt_value "DOMAINS" "Enter all hosted domains separated by spaces" "${DOMAINS}"
  prompt_value "DKIM_SELECTOR" "Enter the DKIM selector" "${DKIM_SELECTOR}"
  prompt_value "SPF_POLICY" "Enter the SPF policy" "${SPF_POLICY}"
  prompt_value "DMARC_POLICY" "Enter the DMARC policy" "${DMARC_POLICY}"
  prompt_value "MX_PRIORITY" "Enter the MX priority" "${MX_PRIORITY}"
  prompt_value "MTA_STS_MODE" "Enter the MTA-STS mode" "${MTA_STS_MODE}"
  prompt_value "DNS_PROVIDER" "Enter the DNS provider" "${DNS_PROVIDER}"
  confirm_yes_no "DDNS_ENABLED" "Enable DDNS planning" "${DDNS_ENABLED}"
}

generate_dns_files() {
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
policy id suggestion: 20260329
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
DNS_PROVIDER: ${DNS_PROVIDER}
DDNS_ENABLED: ${DDNS_ENABLED}
EOF
}

main() {
  print_phase_header "PHASE-09" "dns and identity publishing"
  collect_inputs
  validate_network_exposure_inputs
  if [ "${SAVE_CONFIG}" = "yes" ]; then
    save_network_exposure_configs
  fi
  generate_dns_files
  "${PROJECT_ROOT}/scripts/install/render-network-exposure-configs.ksh"
  log_info "phase 09 completed, dns identity guidance and network-linked dns assets are rendered"
}

main "$@"
