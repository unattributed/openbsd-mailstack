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

DNS_DIR="${PROJECT_ROOT}/services/dns"
DKIM_DIR="${PROJECT_ROOT}/services/dkim"

ZONE_RECORDS="${DNS_DIR}/zone-records.example.generated"
MTA_STS_NOTES="${DNS_DIR}/mta-sts-notes.example.generated"
IDENTITY_SUMMARY="${DNS_DIR}/identity-summary.txt"
DKIM_RECORDS="${DKIM_DIR}/dkim-records.example.generated"

FAIL_COUNT=0
WARN_COUNT=0

pass() { print -- "[$(timestamp)] PASS  $*"; }
warn() { print -- "[$(timestamp)] WARN  $*"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { print -- "[$(timestamp)] FAIL  $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

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

main() {
  print_phase_header "PHASE-09" "dns and identity publishing verification"
  collect_inputs
  validate_hostname "${MAIL_HOSTNAME}" && pass "MAIL_HOSTNAME is valid: ${MAIL_HOSTNAME}" || fail "MAIL_HOSTNAME is invalid"
  validate_domain "${PRIMARY_DOMAIN}" && pass "PRIMARY_DOMAIN is valid: ${PRIMARY_DOMAIN}" || fail "PRIMARY_DOMAIN is invalid"
  validate_space_separated_domains "${DOMAINS}" && pass "DOMAINS contains valid domains" || fail "DOMAINS contains invalid domains"
  validate_selector "${DKIM_SELECTOR}" && pass "DKIM_SELECTOR is valid: ${DKIM_SELECTOR}" || fail "DKIM_SELECTOR is invalid"
  validate_dns_text "${SPF_POLICY}" && pass "SPF_POLICY is present" || fail "SPF_POLICY is empty"
  validate_dns_text "${DMARC_POLICY}" && pass "DMARC_POLICY is present" || fail "DMARC_POLICY is empty"
  validate_numeric "${MX_PRIORITY}" && pass "MX_PRIORITY is valid: ${MX_PRIORITY}" || fail "MX_PRIORITY is invalid"
  validate_selector "${MTA_STS_MODE}" && pass "MTA_STS_MODE is valid: ${MTA_STS_MODE}" || fail "MTA_STS_MODE is invalid"
  for file in "${ZONE_RECORDS}" "${MTA_STS_NOTES}" "${IDENTITY_SUMMARY}" "${DKIM_RECORDS}"; do
    [ -f "${file}" ] && pass "generated file exists: ${file}" || warn "generated file is missing: ${file}"
  done
  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  print
  [ "${FAIL_COUNT}" -eq 0 ]
}

main "$@"
