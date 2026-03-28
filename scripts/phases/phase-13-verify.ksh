#!/bin/ksh
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/services/backup"
MON_DIR="${PROJECT_ROOT}/services/monitoring"

for f in "${BACKUP_DIR}/offhost-replication.example.generated" "${BACKUP_DIR}/restore-drill-checklist.example.generated" "${MON_DIR}/post-restore-validation.example.generated" "${BACKUP_DIR}/phase-13-summary.txt"
do
  if [ -f "${f}" ]; then
    echo "PASS ${f} exists"
  else
    echo "WARN ${f} missing"
  fi
done
