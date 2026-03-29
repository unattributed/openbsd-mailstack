#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${COMMON_LIB}"

BACKUP_DIR="${PROJECT_ROOT}/services/backup"
MON_DIR="${PROJECT_ROOT}/services/monitoring"
SUMMARY_FILE="${BACKUP_DIR}/phase-13-summary.txt"
REPL_FILE="${BACKUP_DIR}/offhost-replication.generated"
DRILL_FILE="${BACKUP_DIR}/restore-drill.generated"
VALIDATION_FILE="${MON_DIR}/post-restore-validation.generated"
UNIFIED_FILE="${BACKUP_DIR}/unified-backup.generated"

load_project_config
prompt_value "BACKUP_OFFSITE_MODE" "Enter the off-host transfer mode" "${BACKUP_OFFSITE_MODE:-ssh}"
prompt_value "BACKUP_OFFSITE_TARGET" "Enter the off-host target" "${BACKUP_OFFSITE_TARGET:-backup@example.net:/srv/openbsd-mailstack}"
prompt_value "DR_SITE_SERVER_NAME" "Enter the DR site server name" "${DR_SITE_SERVER_NAME:-dr.example.com}"
prompt_value "DR_HOST_ENABLED" "Enable the DR host bootstrap, yes or no" "${DR_HOST_ENABLED:-yes}"

validate_mode_word "${BACKUP_OFFSITE_MODE}" || die "invalid BACKUP_OFFSITE_MODE: ${BACKUP_OFFSITE_MODE}"
[ -n "${BACKUP_OFFSITE_TARGET}" ] || die "BACKUP_OFFSITE_TARGET is required"
validate_hostname "${DR_SITE_SERVER_NAME}" || die "invalid DR_SITE_SERVER_NAME: ${DR_SITE_SERVER_NAME}"
validate_yes_no "${DR_HOST_ENABLED}" || die "DR_HOST_ENABLED must be yes or no"

ensure_directory "${BACKUP_DIR}"
ensure_directory "${MON_DIR}"
cat > "${REPL_FILE}" <<EOF
Off-host replication
Dry run: doas ksh scripts/ops/replicate-backup-offhost.ksh --dry-run --run-dir <run-dir>
Apply:   doas ksh scripts/ops/replicate-backup-offhost.ksh --apply --run-dir <run-dir>
Mode: ${BACKUP_OFFSITE_MODE}
Target: ${BACKUP_OFFSITE_TARGET}
EOF
cat > "${DRILL_FILE}" <<EOF
Restore drill
1. use maint/qemu/lab-dr-restore-runner.ksh for a lab rehearsal
2. stage the restore with scripts/ops/run-restore-drill.ksh --archive <archive> --sha256 <sha-file>
3. review extracted files before any live action
4. only then consider scripts/ops/restore-mailstack.ksh --apply-files
EOF
cat > "${UNIFIED_FILE}" <<EOF
Unified backup runner
Dry run: doas ksh scripts/ops/backup-all.ksh --dry-run
Apply:   doas ksh scripts/ops/backup-all.ksh --run
DR host bootstrap enabled: ${DR_HOST_ENABLED}
EOF
cat > "${VALIDATION_FILE}" <<EOF
Post-restore validation
- rcctl check smtpd
- rcctl check dovecot
- rcctl check nginx
- rcctl check rspamd
- rcctl check redis
- verify IMAP login
- verify SMTP submission
- verify webmail access from the trusted path
- verify the DR site at https://${DR_SITE_SERVER_NAME}/dr/
EOF
cat > "${SUMMARY_FILE}" <<EOF
Phase 13 off-host replication and restore testing summary
BACKUP_OFFSITE_MODE: ${BACKUP_OFFSITE_MODE}
BACKUP_OFFSITE_TARGET: ${BACKUP_OFFSITE_TARGET}
DR_SITE_SERVER_NAME: ${DR_SITE_SERVER_NAME}
DR_HOST_ENABLED: ${DR_HOST_ENABLED}
EOF
log_info "phase 13 off-host replication and restore testing completed"
