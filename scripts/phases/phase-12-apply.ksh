#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
PROFILE_LIB="${PROJECT_ROOT}/scripts/lib/backup-dr-phase-profiles.ksh"
. "${COMMON_LIB}"
. "${PROFILE_LIB}"

PLAN_DIR="$(backupdr_profile_phase_dir 12)"
SUMMARY_FILE="${PLAN_DIR}/phase-12-summary.txt"
INTEGRITY_FILE="${PLAN_DIR}/integrity-workflow.txt"
RESTORE_MODES_FILE="${PLAN_DIR}/restore-modes.txt"
PROTECT_FILE="${PLAN_DIR}/archive-protection.txt"

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

backupdr_profile_write_text "${INTEGRITY_FILE}" "Integrity workflow
1. run backup helpers to produce .tgz, manifest.txt, and .sha256 files
2. verify with: doas ksh scripts/ops/verify-backup-set.ksh --run-dir <run-dir>
3. use scripts/ops/protect-backup-set.ksh to sign or encrypt the archive set
4. never restore before the manifest and hash are verified"
backupdr_profile_write_text "${RESTORE_MODES_FILE}" "Restore modes
Default mode is staged and non-destructive.
Live file restoration requires:
- doas
- RESTORE_ALLOW_OVERWRITE=yes
- explicit use of scripts/ops/restore-mailstack.ksh --apply-files
Database import is a separate explicit action with --apply-database."
backupdr_profile_write_text "${PROTECT_FILE}" "Archive protection
Signify enabled: ${BACKUP_ENABLE_SIGNIFY}
GPG enabled: ${BACKUP_ENABLE_GPG}
Protect command: doas ksh scripts/ops/protect-backup-set.ksh --run --run-dir <run-dir>"
backupdr_profile_write_text "${SUMMARY_FILE}" "Phase 12 advanced backup security and integrity summary
BACKUP_ENABLE_SIGNIFY: ${BACKUP_ENABLE_SIGNIFY}
BACKUP_SIGNIFY_SECRET_KEY: ${BACKUP_SIGNIFY_SECRET_KEY}
BACKUP_ENABLE_GPG: ${BACKUP_ENABLE_GPG}
BACKUP_GPG_RECIPIENT: ${BACKUP_GPG_RECIPIENT}
BACKUP_MANIFEST_MODE: ${BACKUP_MANIFEST_MODE}
RESTORE_ALLOW_OVERWRITE: ${RESTORE_ALLOW_OVERWRITE}
plan directory: ${PLAN_DIR}"
log_info "phase 12 advanced backup security and integrity completed"
log_info "generated live plan pack in ${PLAN_DIR}"
