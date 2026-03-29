#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${PROJECT_ROOT}/scripts/lib/network-exposure.ksh"

DNS_DIR="${PROJECT_ROOT}/services/dns"
DKIM_DIR="${PROJECT_ROOT}/services/dkim"

main() {
  print_phase_header "PHASE-09" "dns and identity publishing verification"
  load_network_exposure_config
  validate_network_exposure_inputs
  for file in         "${DNS_DIR}/zone-records.example.generated"         "${DNS_DIR}/mta-sts-notes.example.generated"         "${DNS_DIR}/identity-summary.txt"         "${DKIM_DIR}/dkim-records.example.generated"; do
    [ -f "${file}" ] || die "missing generated dns identity file: ${file}"
  done
  "${PROJECT_ROOT}/scripts/verify/verify-network-exposure-assets.ksh"
  log_info "phase 09 verification completed successfully"
}

main "$@"
