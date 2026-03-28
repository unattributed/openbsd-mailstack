#!/bin/ksh
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AUTH_DIR="${PROJECT_ROOT}/services/auth"
DOVECOT_DIR="${PROJECT_ROOT}/services/dovecot"
ROUNDCUBE_DIR="${PROJECT_ROOT}/services/roundcube"

mkdir -p "${AUTH_DIR}" "${DOVECOT_DIR}" "${ROUNDCUBE_DIR}"

cat > "${AUTH_DIR}/authentication-policy.example.generated" <<'EOF'
Authentication policy baseline
- Require strong unique passwords for all mailbox accounts
- Keep VPN-only access for webmail and admin surfaces during MVP
- Keep TLS mandatory for client and web access
- Review account lifecycle regularly
- Avoid shared accounts where possible
- Treat second factor as staged design work, not a blind universal mandate
EOF

cat > "${AUTH_DIR}/password-policy.example.generated" <<'EOF'
Password policy guidance
- Minimum length: 16 characters
- Unique per account
- Use password manager-generated values
- Rotate on suspected compromise
- Do not reuse mailbox passwords for admin services
EOF

cat > "${AUTH_DIR}/second-factor-roadmap.example.generated" <<'EOF'
Second-factor roadmap
Stage 1:
- Strong passwords
- VPN-only web/admin access
- Operational review

Stage 2:
- Evaluate second factor for Roundcube and admin surfaces
- Validate compatibility and recovery flow

Stage 3:
- Evaluate app-password or gateway-style advanced auth for legacy clients
- Do not promise universal Thunderbird TOTP support without validated architecture
EOF

cat > "${DOVECOT_DIR}/dovecot-auth-hardening-notes.example.generated" <<'EOF'
Dovecot hardening notes
- Require TLS for client access
- Limit auth exposure to required services only
- Review auth failure logs
- Keep password storage aligned to a strong supported scheme
- Do not bolt on incompatible second-factor claims at the IMAP layer
EOF

cat > "${ROUNDCUBE_DIR}/roundcube-auth-hardening-notes.example.generated" <<'EOF'
Roundcube hardening notes
- Keep Roundcube behind WireGuard during MVP
- Keep TLS mandatory
- Review plugin compatibility before introducing second factor
- Prefer staged rollout with recovery testing
EOF

cat > "${AUTH_DIR}/phase-15-summary.txt" <<EOF
Phase 15 security hardening and authentication baseline generated
EOF

echo "Phase 15 completed"
