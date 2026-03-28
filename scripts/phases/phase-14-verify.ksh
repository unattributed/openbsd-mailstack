#!/bin/ksh
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MON_DIR="${PROJECT_ROOT}/services/monitoring"
OPS_DIR="${PROJECT_ROOT}/services/ops"

for f in \
"${MON_DIR}/monitoring-checklist.example.generated" \
"${OPS_DIR}/service-review.example.generated" \
"${MON_DIR}/daily-report.example.generated" \
"${MON_DIR}/monitoring-summary.txt"
do
  if [ -f "${f}" ]; then
    echo "PASS ${f} exists"
  else
    echo "WARN ${f} missing"
  fi
done
