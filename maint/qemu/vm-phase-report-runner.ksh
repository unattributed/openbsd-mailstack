#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

PHASE_NUM=""
REPORT_DIR="/home/foo/phase-reports"

usage() {
  cat <<'USAGE'
usage: vm-phase-report-runner.ksh --phase NN [--report-dir DIR]
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --phase) PHASE_NUM="$2"; shift 2 ;;
    --report-dir) REPORT_DIR="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[ -n "$PHASE_NUM" ] || { usage >&2; exit 1; }

PHASE_APPLY="./scripts/phases/phase-${PHASE_NUM}-apply.ksh"
PHASE_VERIFY="./scripts/phases/phase-${PHASE_NUM}-verify.ksh"

mkdir -p "${REPORT_DIR}"
REPORT_FILE="${REPORT_DIR}/phase-${PHASE_NUM}.log"

{
  echo "=== phase ${PHASE_NUM} apply ==="
  ksh "${PHASE_APPLY}"
  echo "=== phase ${PHASE_NUM} verify ==="
  ksh "${PHASE_VERIFY}"
} >"${REPORT_FILE}" 2>&1

echo "Report written to ${REPORT_FILE}"
