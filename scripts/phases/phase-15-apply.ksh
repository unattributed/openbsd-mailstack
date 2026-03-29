#!/bin/ksh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"

load_project_config

: "${DOAS_BREAKGLASS_GROUP:=wheel}"
: "${DOAS_NOPASS_USER:=${SUDO_USER:-${USER:-operator}}}"
: "${DOAS_AUTOMATION_OVERLAY_PATH:=/etc/doas-automation-local.conf}"
: "${DOAS_TRANSITION_ALLOW_CMDS:=true install rcctl pfctl sshd:-t sshd:-T crontab}"
: "${SSH_PERMIT_ROOT_LOGIN:=no}"
: "${SSH_PASSWORD_AUTHENTICATION:=no}"
: "${SSH_KBDINTERACTIVE_AUTHENTICATION:=no}"
: "${SSH_PUBKEY_AUTHENTICATION:=yes}"
: "${SSH_MAX_AUTH_TRIES:=4}"
: "${SSH_MAX_SESSIONS:=8}"
: "${SSH_CLIENT_ALIVE_INTERVAL:=300}"
: "${SSH_CLIENT_ALIVE_COUNT_MAX:=2}"
: "${SSH_LOGIN_GRACE_TIME:=30}"
: "${AUTH_PASSWORD_MIN_LENGTH:=16}"
: "${AUTH_WEB_VPN_ONLY:=yes}"
: "${AUTH_ADMIN_VPN_ONLY:=yes}"
: "${AUTH_SECOND_FACTOR_STAGE:=plan}"
: "${AUTH_ROUNDCUBE_SECOND_FACTOR:=evaluate}"
: "${AUTH_POSTFIXADMIN_SECOND_FACTOR:=evaluate}"

OUT_DIR="${PROJECT_ROOT}/services/generated/rootfs/etc/examples/openbsd-mailstack"
mkdir -p "${OUT_DIR}"

${PROJECT_ROOT}/maint/doas-policy-baseline-check.ksh --render > "${OUT_DIR}/doas.conf.baseline"
${PROJECT_ROOT}/maint/doas-policy-transition.ksh --render > "${OUT_DIR}/doas.conf.command-scoped"
cat > "${OUT_DIR}/sshd_config.phase15" <<EOF
PermitRootLogin ${SSH_PERMIT_ROOT_LOGIN}
PasswordAuthentication ${SSH_PASSWORD_AUTHENTICATION}
KbdInteractiveAuthentication ${SSH_KBDINTERACTIVE_AUTHENTICATION}
PubkeyAuthentication ${SSH_PUBKEY_AUTHENTICATION}
MaxAuthTries ${SSH_MAX_AUTH_TRIES}
MaxSessions ${SSH_MAX_SESSIONS}
ClientAliveInterval ${SSH_CLIENT_ALIVE_INTERVAL}
ClientAliveCountMax ${SSH_CLIENT_ALIVE_COUNT_MAX}
LoginGraceTime ${SSH_LOGIN_GRACE_TIME}
EOF

cat > "${OUT_DIR}/authentication-policy.txt" <<EOF
Authentication policy baseline
- Require passwords of at least ${AUTH_PASSWORD_MIN_LENGTH} characters.
- Keep webmail VPN-only during the public-safe baseline: ${AUTH_WEB_VPN_ONLY}.
- Keep admin surfaces VPN-only during the public-safe baseline: ${AUTH_ADMIN_VPN_ONLY}.
- Keep TLS mandatory for client and web access.
- Treat second-factor rollout as staged work, current stage: ${AUTH_SECOND_FACTOR_STAGE}.
- Roundcube second-factor status: ${AUTH_ROUNDCUBE_SECOND_FACTOR}.
- PostfixAdmin second-factor status: ${AUTH_POSTFIXADMIN_SECOND_FACTOR}.
EOF

cat > "${OUT_DIR}/password-policy.txt" <<EOF
Password policy guidance
- Minimum length: ${AUTH_PASSWORD_MIN_LENGTH}
- Unique per account
- Use password manager-generated values
- Rotate on suspected compromise
- Do not reuse mailbox passwords for admin services
EOF

cat > "${OUT_DIR}/second-factor-roadmap.txt" <<EOF
Second-factor roadmap
Stage 1
- Strong passwords
- VPN-only web and admin access
- Operational review of auth failures

Stage 2
- Validate Roundcube and PostfixAdmin second-factor compatibility
- Test recovery and operator lockout procedures

Stage 3
- Evaluate app-password or gateway-assisted models for legacy mail clients
EOF

cat > "${OUT_DIR}/phase-15-summary.txt" <<EOF
Phase 15 security hardening baseline rendered
- doas baseline policy example
- command-scoped doas policy example
- sshd hardening example
- authentication policy and roadmap artifacts
EOF

print -- "Phase 15 completed"
