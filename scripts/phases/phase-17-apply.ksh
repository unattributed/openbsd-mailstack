#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
ADVANCED_LIB="${PROJECT_ROOT}/scripts/lib/advanced-gap-rollout.ksh"
PROFILE_LIB="${PROJECT_ROOT}/scripts/lib/advanced-phase-profiles.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing common library: ${COMMON_LIB}" >&2
  exit 1
}
[ -f "${ADVANCED_LIB}" ] || {
  print -- "ERROR missing advanced rollout library: ${ADVANCED_LIB}" >&2
  exit 1
}
[ -f "${PROFILE_LIB}" ] || {
  print -- "ERROR missing advanced profile library: ${PROFILE_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"
. "${ADVANCED_LIB}"
. "${PROFILE_LIB}"

PLAN_DIR="$(advanced_profile_phase_dir 17)"
SURICATA_PLAN="${PLAN_DIR}/suricata-plan.txt"
BREVO_PLAN="${PLAN_DIR}/brevo-webhook-plan.txt"
SOGO_PLAN="${PLAN_DIR}/sogo-plan.txt"
SBOM_PLAN="${PLAN_DIR}/sbom-plan.txt"
PHASE_SUMMARY="${PLAN_DIR}/phase-17-summary.txt"

main() {
  print_phase_header "PHASE-17" "advanced optional integrations and gap closures"
  advanced_load_config
  validate_advanced_inputs

  ksh "${PROJECT_ROOT}/scripts/install/render-advanced-gap-configs.ksh"

  advanced_profile_write_text "${SURICATA_PLAN}" "Suricata optional plan
enabled: ${ENABLE_SURICATA}
interface: ${SURICATA_INTERFACE}
rules directory: ${SURICATA_RULE_DIR}
log directory: ${SURICATA_LOG_DIR}
rendered asset root: ${OPENBSD_MAILSTACK_ADVANCED_RENDER_ROOT:-${PROJECT_ROOT}/.work/advanced/rootfs}/etc/suricata"

  advanced_profile_write_text "${BREVO_PLAN}" "Brevo webhook optional plan
enabled: ${ENABLE_BREVO_WEBHOOK}
listen address: ${BREVO_WEBHOOK_LISTEN_ADDR}
listen port: ${BREVO_WEBHOOK_LISTEN_PORT}
url path: ${BREVO_WEBHOOK_URL_PATH}
rendered nginx template: ${OPENBSD_MAILSTACK_ADVANCED_RENDER_ROOT:-${PROJECT_ROOT}/.work/advanced/rootfs}/etc/nginx/templates/${BREVO_WEBHOOK_NGINX_TEMPLATE_NAME}"

  advanced_profile_write_text "${SOGO_PLAN}" "SOGo optional plan
enabled: ${ENABLE_SOGO}
mail domain: ${SOGO_MAIL_DOMAIN}
database name: ${SOGO_DB_NAME}
listen address: ${SOGO_LISTEN_ADDR}
listen port: ${SOGO_LISTEN_PORT}
rendered config: ${OPENBSD_MAILSTACK_ADVANCED_RENDER_ROOT:-${PROJECT_ROOT}/.work/advanced/rootfs}/etc/sogo/sogo.conf"

  advanced_profile_write_text "${SBOM_PLAN}" "SBOM optional plan
enabled: ${ENABLE_SBOM}
scanner mode: ${SBOM_SCANNER_MODE}
report email: ${SBOM_REPORT_EMAIL}
rendered sbom root: ${OPENBSD_MAILSTACK_ADVANCED_SBOM_ROOT:-${PROJECT_ROOT}/.work/advanced/sbom}
source SBOM entrypoint: ${PROJECT_ROOT}/scripts/ops/sbom-source-spdx.ksh
host inventory entrypoint: ${PROJECT_ROOT}/scripts/ops/sbom-host-inventory.ksh"

  advanced_profile_write_text "${PHASE_SUMMARY}" "Phase 17 advanced optional integrations summary
plan directory: ${PLAN_DIR}
readiness report path: $(advanced_readiness_dir)/advanced-readiness.txt
suricata enabled: ${ENABLE_SURICATA}
brevo webhook enabled: ${ENABLE_BREVO_WEBHOOK}
sogo enabled: ${ENABLE_SOGO}
sbom enabled: ${ENABLE_SBOM}"

  log_info "phase 17 completed successfully"
  log_info "generated live advanced optional plan pack in ${PLAN_DIR}"
}

main "$@"
