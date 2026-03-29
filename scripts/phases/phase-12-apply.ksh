#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${COMMON_LIB}"

BACKUP_DIR="${PROJECT_ROOT}/services/backup"
SUMMARY_FILE="${BACKUP_DIR}/phase-12-summary.txt"
INTEGRITY_FILE="${BACKUP_DIR}/integrity-workflow.generated"
RESTORE_MODES_FILE="${BACKUP_DIR}/restore-modes.generated"

load_project_config
prompt_value "BACKUP_ENABLE_SIGNIFY" "Enable signify signing, yes or no" "${BACKUP_ENABLE_SIGNIFY:-no}"
prompt_value "BACKUP_SIGNIFY_SECRET_KEY" "Enter the signify secret key path" "${BACKUP_SIGNIFY_SECRET_KEY:-/root/.signify/openbsd-mailstack-backup.sec}"
prompt_value "BACKUP_ENABLE_GPG" "Enable GPG encryption, yes or no" "${BACKUP_ENABLE_GPG:-no}"
prompt_value "BACKUP_GPG_RECIPIENT" "Enter the GPG recipient, leave empty if disabled" "${BACKUP_GPG_RECIPIENT:-}"
prompt_value "BACKUP_MANIFEST_MODE" "Enter the manifest mode" "${BACKUP_MANIFEST_MODE:-sha256}"
prompt_value "RESTORE_ALLOW_OVERWRITE" "Allow direct overwrite, yes or no" "${RESTORE_ALLOW_OVERWRITE:-no}"

validate_yes_no "${BACKUP_ENABLE_SIGNIFY}" || die "BACKUP_ENABLE_SIGNIFY must be yes or no"
validate_yes_no "${BACKUP_ENABLE_GPG}" || die "BACKUP_ENABLE_GPG must be yes or no"
validate_mode_word "${BACKUP_MANIFEST_MODE}" || die "invalid BACKUP_MANIFEST_MODE: ${BACKUP_MANIFEST_MODE}"
validate_yes_no "${RESTORE_ALLOW_OVERWRITE}" || die "RESTORE_ALLOW_OVERWRITE must be yes or no"

ensure_directory "${BACKUP_DIR}"
cat > "${INTEGRITY_FILE}" <<EOF
Integrity workflow
1. run backup helpers to produce .tgz, manifest.txt, and .sha256 files
2. verify with: doas ksh scripts/ops/verify-backup-set.ksh --run-dir <run-dir>
3. if BACKUP_ENABLE_SIGNIFY=yes, sign the archive with ${BACKUP_SIGNIFY_SECRET_KEY}
4. if BACKUP_ENABLE_GPG=yes, encrypt a copy for ${BACKUP_GPG_RECIPIENT:-operator-supplied-recipient}
5. never restore before the manifest and hash are verified
EOF
cat > "${RESTORE_MODES_FILE}" <<EOF
Restore modes
Default mode is staged and non-destructive.
Live file restoration requires:
- doas
- RESTORE_ALLOW_OVERWRITE=yes
- explicit use of scripts/ops/restore-mailstack.ksh --apply-files
Database import is a separate explicit action with --apply-database.
EOF
cat > "${SUMMARY_FILE}" <<EOF
Phase 12 advanced backup security and integrity summary
BACKUP_ENABLE_SIGNIFY: ${BACKUP_ENABLE_SIGNIFY}
BACKUP_SIGNIFY_SECRET_KEY: ${BACKUP_SIGNIFY_SECRET_KEY}
BACKUP_ENABLE_GPG: ${BACKUP_ENABLE_GPG}
BACKUP_GPG_RECIPIENT: ${BACKUP_GPG_RECIPIENT}
BACKUP_MANIFEST_MODE: ${BACKUP_MANIFEST_MODE}
RESTORE_ALLOW_OVERWRITE: ${RESTORE_ALLOW_OVERWRITE}
EOF
log_info "phase 12 advanced backup security and integrity completed"
