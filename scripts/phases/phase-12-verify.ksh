#!/bin/ksh
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/services/backup"

for f in backup-encryption.example.generated backup-manifest.example.generated backup-verify.example.generated integrity-summary.txt
do
  if [ -f "${BACKUP_DIR}/$f" ]; then
    echo "PASS $f exists"
  else
    echo "WARN $f missing"
  fi
done
