#!/bin/ksh
set -e
set -o pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"

print -- "=== PF health ==="
"${PROJECT_ROOT}/scripts/ops/pf-health-report.ksh" || true
print
print -- "=== WireGuard smoketest ==="
"${PROJECT_ROOT}/scripts/ops/wg-smoketest.ksh" || true
print
print -- "=== DNS zone check ==="
"${PROJECT_ROOT}/scripts/ops/dns-zone-check.ksh" || true
print
print -- "=== DDNS preview ==="
"${PROJECT_ROOT}/scripts/ops/ddns-sync-preview.ksh" || true
