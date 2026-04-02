#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
PROFILE_LIB="${PROJECT_ROOT}/scripts/lib/backup-dr-phase-profiles.ksh"
. "${COMMON_LIB}"
. "${PROFILE_LIB}"

PLAN_DIR="$(backupdr_profile_phase_dir 13)"
SUMMARY_FILE="${PLAN_DIR}/phase-13-summary.txt"
REPL_FILE="${PLAN_DIR}/offhost-replication.txt"
DRILL_FILE="${PLAN_DIR}/restore-drill.txt"
VALIDATION_FILE="${PLAN_DIR}/post-restore-validation.txt"
UNIFIED_FILE="${PLAN_DIR}/unified-backup.txt"

load_project_config
prompt_value "BACKUP_OFFSITE_MODE" "Enter the off-host transfer mode" "${BACKUP_OFFSITE_MODE:-ssh}"
prompt_value "BACKUP_OFFSITE_TARGET" "Enter the off-host target" "${BACKUP_OFFSITE_TARGET:-backup@example.net:/srv/openbsd-mailstack}"
prompt_value "DR_SITE_SERVER_NAME" "Enter the DR site server name" "${DR_SITE_SERVER_NAME:-dr.example.com}"
prompt_value "DR_HOST_ENABLED" "Enable the DR host bootstrap, yes or no" "${DR_HOST_ENABLED:-yes}"

validate_mode_word "${BACKUP_OFFSITE_MODE}" || die "invalid BACKUP_OFFSITE_MODE: ${BACKUP_OFFSITE_MODE}"
[ -n "${BACKUP_OFFSITE_TARGET}" ] || die "BACKUP_OFFSITE_TARGET is required"
validate_hostname "${DR_SITE_SERVER_NAME}" || die "invalid DR_SITE_SERVER_NAME: ${DR_SITE_SERVER_NAME}"
validate_yes_no "${DR_HOST_ENABLED}" || die "DR_HOST_ENABLED must be yes or no"

backupdr_profile_write_text "${REPL_FILE}" "Off-host replication
Dry run: doas ksh scripts/ops/replicate-backup-offhost.ksh --dry-run --run-dir <run-dir>
Apply:   doas ksh scripts/ops/replicate-backup-offhost.ksh --apply --run-dir <run-dir>
Mode: ${BACKUP_OFFSITE_MODE}
Target: ${BACKUP_OFFSITE_TARGET}"
backupdr_profile_write_text "${DRILL_FILE}" "Restore drill
1. use maint/qemu/lab-dr-restore-runner.ksh for a lab rehearsal
2. stage the restore with scripts/ops/run-restore-drill.ksh --archive <archive> --sha256 <sha-file>
3. review extracted files before any live action
4. only then consider scripts/ops/restore-mailstack.ksh --apply-files"
backupdr_profile_write_text "${UNIFIED_FILE}" "Unified backup runner
Dry run: doas ksh scripts/ops/backup-all.ksh --dry-run
Apply:   doas ksh scripts/ops/backup-all.ksh --run
DR host bootstrap enabled: ${DR_HOST_ENABLED}"
backupdr_profile_write_text "${VALIDATION_FILE}" "Post-restore validation
- rcctl check smtpd
- rcctl check dovecot
- rcctl check nginx
- rcctl check rspamd
- rcctl check redis
- verify IMAP login
- verify SMTP submission
- verify webmail access from the trusted path
- verify the DR site at https://${DR_SITE_SERVER_NAME}/dr/"
backupdr_profile_write_text "${SUMMARY_FILE}" "Phase 13 off-host replication and restore testing summary
BACKUP_OFFSITE_MODE: ${BACKUP_OFFSITE_MODE}
BACKUP_OFFSITE_TARGET: ${BACKUP_OFFSITE_TARGET}
DR_SITE_SERVER_NAME: ${DR_SITE_SERVER_NAME}
DR_HOST_ENABLED: ${DR_HOST_ENABLED}
plan directory: ${PLAN_DIR}"
log_info "phase 13 off-host replication and restore testing completed"
log_info "generated live plan pack in ${PLAN_DIR}"
