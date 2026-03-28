#!/bin/ksh
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS_DIR="${PROJECT_ROOT}/services/secrets"
KEYS_DIR="${PROJECT_ROOT}/services/keys"

for f in \
"${SECRETS_DIR}/secret-inventory.example.generated" \
"${KEYS_DIR}/key-material-inventory.example.generated" \
"${SECRETS_DIR}/rotation-checklist.example.generated" \
"${KEYS_DIR}/secure-storage-notes.example.generated" \
"${SECRETS_DIR}/phase-16-summary.txt"
do
  if [ -f "${f}" ]; then
    echo "PASS ${f} exists"
  else
    echo "WARN ${f} missing"
  fi
done
