#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${PROJECT_ROOT}/scripts/lib/network-exposure.ksh"

IDENTITY_ROOT="$(identity_render_root)"
DNS_DIR="${IDENTITY_ROOT}/dns"
DKIM_DIR="${IDENTITY_ROOT}/dkim"

main() {
  print_phase_header "PHASE-09" "dns and identity publishing verification"
  load_network_exposure_config
  validate_network_exposure_inputs
  for file in         "${DNS_DIR}/zone-records.generated"         "${DNS_DIR}/mta-sts-notes.generated"         "${IDENTITY_ROOT}/identity-summary.txt"         "${DKIM_DIR}/dkim-records.generated"; do
    [ -f "${file}" ] || die "missing generated dns identity file: ${file}"
  done
  "${PROJECT_ROOT}/scripts/verify/verify-network-exposure-assets.ksh"
  log_info "phase 09 verification completed successfully"
}

main "$@"
