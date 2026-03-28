#!/bin/ksh
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS_DIR="${PROJECT_ROOT}/services/secrets"
KEYS_DIR="${PROJECT_ROOT}/services/keys"

mkdir -p "${SECRETS_DIR}" "${KEYS_DIR}"

cat > "${SECRETS_DIR}/secret-inventory.example.generated" <<'EOF'
Secret inventory guidance
- MariaDB root password
- PostfixAdmin database password
- Dovecot database password
- Postfix database password
- API keys
- operational alerting credentials, if any

Rules
- do not commit live values
- store outside Git
- review owners and modes
EOF

cat > "${KEYS_DIR}/key-material-inventory.example.generated" <<'EOF'
Key material inventory guidance
- TLS private key
- DKIM private keys
- backup signing or encryption keys

Rules
- do not commit private keys
- keep backup copies encrypted
- document restore access path
EOF

cat > "${SECRETS_DIR}/rotation-checklist.example.generated" <<'EOF'
Rotation checklist
1. Identify secret or key to rotate
2. Identify dependent services
3. Generate replacement value or keypair
4. Update configuration safely
5. Reload or restart impacted services
6. Verify service functionality
7. Revoke or remove old material
8. Update backup and DR references
EOF

cat > "${KEYS_DIR}/secure-storage-notes.example.generated" <<'EOF'
Secure storage notes
- Store live secrets outside Git
- Prefer encrypted backups for private key material
- Keep access limited to required operators
- Review file permissions regularly
- Test recovery workflow before relying on stored material
EOF

cat > "${SECRETS_DIR}/phase-16-summary.txt" <<EOF
Phase 16 secrets handling and key material baseline generated
EOF

echo "Phase 16 completed"
