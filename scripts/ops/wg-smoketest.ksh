#!/bin/ksh
set -e
set -o pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${PROJECT_ROOT}/scripts/lib/network-exposure.ksh"

load_network_exposure_config
validate_network_exposure_inputs
ifconfig "${WIREGUARD_INTERFACE}" 2>/dev/null || die "WireGuard interface not found: ${WIREGUARD_INTERFACE}"
if command -v wg >/dev/null 2>&1; then
  wg show "${WIREGUARD_INTERFACE}" || true
fi
print -- "expected subnet: ${WIREGUARD_SUBNET}"
print -- "expected admin policy: VPN-only=${ADMIN_VPN_ONLY}"
