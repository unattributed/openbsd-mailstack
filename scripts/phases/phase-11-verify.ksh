#!/bin/ksh
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OPS_DIR="${PROJECT_ROOT}/services/backup"

for f in backup-scope.example.generated backup-script.example.generated restore-runbook.example.generated dr-summary.txt
do
  if [ -f "${OPS_DIR}/$f" ]; then
    echo "PASS $f exists"
  else
    echo "WARN $f missing"
  fi
done
