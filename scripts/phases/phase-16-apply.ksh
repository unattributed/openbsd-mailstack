#!/bin/ksh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"

load_project_config

: "${RUNTIME_SECRET_DIR:=/root/.config/openbsd-mailstack/runtime}"
: "${RUNTIME_PROVIDER_DIR:=/root/.config/openbsd-mailstack/providers}"
: "${RUNTIME_DR_DIR:=/root/.config/openbsd-mailstack/dr}"
: "${POSTFIXADMIN_DB_ENV_PATH:=${RUNTIME_SECRET_DIR}/postfixadmin-db.env}"
: "${SOGO_DB_ENV_PATH:=${RUNTIME_SECRET_DIR}/sogo-db.env}"
: "${POSTFIXADMIN_SECRETS_PHP_PATH:=/etc/postfixadmin/secrets.php}"
: "${ROUNDCUBE_SECRETS_INC_PHP_PATH:=/etc/roundcube/secrets.inc.php}"
: "${VIRUSTOTAL_ENV_PATH:=${RUNTIME_PROVIDER_DIR}/virustotal.env}"
: "${DR_RUNTIME_ENV_PATH:=${RUNTIME_DR_DIR}/obsd1.env}"
: "${DR_GITHUB_PAT_PATH:=${RUNTIME_DR_DIR}/github.pat}"
: "${RUNTIME_SECRET_OWNER:=root}"
: "${RUNTIME_SECRET_GROUP:=wheel}"
: "${RUNTIME_SECRET_FILE_MODE:=0600}"
: "${RUNTIME_SECRET_DIR_MODE:=0700}"

OUT_DIR="${PROJECT_ROOT}/services/generated/rootfs/etc/examples/openbsd-mailstack"
mkdir -p "${OUT_DIR}"
install -m 0644 "${PROJECT_ROOT}/services/secrets/etc/examples/postfixadmin-db.env.template" "${OUT_DIR}/postfixadmin-db.env"
install -m 0644 "${PROJECT_ROOT}/services/secrets/etc/examples/sogo-db.env.template" "${OUT_DIR}/sogo-db.env"
install -m 0644 "${PROJECT_ROOT}/services/secrets/etc/postfixadmin/secrets.php.template" "${PROJECT_ROOT}/services/generated/rootfs/etc/postfixadmin/secrets.php.example"
install -m 0644 "${PROJECT_ROOT}/services/secrets/etc/roundcube/secrets.inc.php.template" "${PROJECT_ROOT}/services/generated/rootfs/etc/roundcube/secrets.inc.php.example"

cat > "${OUT_DIR}/runtime-secret-paths.txt" <<EOF
Runtime secret layout
Directories
- ${RUNTIME_SECRET_DIR}
- ${RUNTIME_PROVIDER_DIR}
- ${RUNTIME_DR_DIR}
- /etc/postfixadmin
- /etc/roundcube

Files
- ${POSTFIXADMIN_DB_ENV_PATH}
- ${SOGO_DB_ENV_PATH}
- ${POSTFIXADMIN_SECRETS_PHP_PATH}
- ${ROUNDCUBE_SECRETS_INC_PHP_PATH}
- ${VIRUSTOTAL_ENV_PATH}
- ${DR_RUNTIME_ENV_PATH}
- ${DR_GITHUB_PAT_PATH}
EOF

cat > "${OUT_DIR}/runtime-secret-permissions.txt" <<EOF
Ownership and mode expectations
- owner=${RUNTIME_SECRET_OWNER}
- group=${RUNTIME_SECRET_GROUP}
- dir mode=${RUNTIME_SECRET_DIR_MODE}
- file mode=${RUNTIME_SECRET_FILE_MODE}
EOF

cat > "${OUT_DIR}/rotation-checklist.txt" <<EOF
Rotation checklist
1. Identify secret or key to rotate
2. Identify dependent services
3. Generate replacement value or keypair
4. Update host-local runtime files
5. Reload or restart impacted services
6. Verify service functionality
7. Revoke or remove old material
8. Update backup and recovery references
EOF

cat > "${OUT_DIR}/phase-16-summary.txt" <<EOF
Phase 16 runtime secret handling baseline rendered
- host-local runtime secret layout
- permissions guidance
- PostfixAdmin and Roundcube runtime secret examples
- database env file examples
EOF

print -- "Phase 16 completed"
