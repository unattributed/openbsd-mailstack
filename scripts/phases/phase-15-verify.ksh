#!/bin/ksh
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AUTH_DIR="${PROJECT_ROOT}/services/auth"
DOVECOT_DIR="${PROJECT_ROOT}/services/dovecot"
ROUNDCUBE_DIR="${PROJECT_ROOT}/services/roundcube"

for f in \
"${AUTH_DIR}/authentication-policy.example.generated" \
"${AUTH_DIR}/password-policy.example.generated" \
"${AUTH_DIR}/second-factor-roadmap.example.generated" \
"${DOVECOT_DIR}/dovecot-auth-hardening-notes.example.generated" \
"${ROUNDCUBE_DIR}/roundcube-auth-hardening-notes.example.generated" \
"${AUTH_DIR}/phase-15-summary.txt"
do
  if [ -f "${f}" ]; then
    echo "PASS ${f} exists"
  else
    echo "WARN ${f} missing"
  fi
done
