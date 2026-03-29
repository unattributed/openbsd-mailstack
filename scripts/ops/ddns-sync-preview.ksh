#!/bin/ksh
set -e
set -o pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${PROJECT_ROOT}/scripts/lib/network-exposure.ksh"

load_network_exposure_config
validate_network_exposure_inputs
export DDNS_DOMAINS DDNS_HOST_LABELS DDNS_TARGET_IPV4 DDNS_TTL DDNS_API_URL DDNS_PROVIDER DDNS_ENABLED VULTR_API_KEY
exec python3 "${PROJECT_ROOT}/scripts/ops/vultr-ddns-sync.py" --dry-run
