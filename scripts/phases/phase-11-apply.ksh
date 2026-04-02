#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
PROFILE_LIB="${PROJECT_ROOT}/scripts/lib/backup-dr-phase-profiles.ksh"
. "${COMMON_LIB}"
. "${PROFILE_LIB}"

PLAN_DIR="$(backupdr_profile_phase_dir 11)"
SUMMARY_FILE="${PLAN_DIR}/phase-11-summary.txt"
SCOPE_FILE="${PLAN_DIR}/backup-scope.txt"
RESTORE_FILE="${PLAN_DIR}/restore-workflow.txt"
DR_SITE_FILE="${PLAN_DIR}/dr-site-provisioning.txt"
SCHEDULE_FILE="${PLAN_DIR}/backup-schedule.txt"
DR_HOST_FILE="${PLAN_DIR}/dr-host-bootstrap.txt"

load_project_config
prompt_value "MAIL_HOSTNAME" "Enter the public mail hostname" "${MAIL_HOSTNAME:-mail.example.com}"
prompt_value "BACKUP_ROOT" "Enter the backup root directory" "${BACKUP_ROOT:-/var/backups/openbsd-mailstack}"
prompt_value "BACKUP_RETENTION_DAYS" "Enter backup retention in days" "${BACKUP_RETENTION_DAYS:-30}"
prompt_value "BACKUP_DATABASES" "Enter space separated databases to dump" "${BACKUP_DATABASES:-mysql postfixadmin roundcube}"
prompt_value "BACKUP_CONFIG_PATHS" "Enter config backup paths" "${BACKUP_CONFIG_PATHS:-/etc /etc/ssl /etc/ssl/private /var/www /var/db/acme}"
prompt_value "BACKUP_MAIL_PATHS" "Enter mail storage paths" "${BACKUP_MAIL_PATHS:-/var/vmail}"
prompt_value "BACKUP_RUNTIME_PATHS" "Enter runtime paths" "${BACKUP_RUNTIME_PATHS:-/var/spool/postfix /var/db/redis /var/db/clamav /var/log}"
prompt_value "RESTORE_STAGING_DIR" "Enter the restore staging directory" "${RESTORE_STAGING_DIR:-/var/restore/openbsd-mailstack}"
prompt_value "DR_SITE_ENABLED" "Enable the DR site, yes or no" "${DR_SITE_ENABLED:-yes}"
prompt_value "DR_SITE_SERVER_NAME" "Enter the DR site server name" "${DR_SITE_SERVER_NAME:-dr.example.com}"
prompt_value "DR_HOST_ENABLED" "Enable the DR host bootstrap, yes or no" "${DR_HOST_ENABLED:-yes}"
prompt_value "BACKUP_CRON_ENABLED" "Enable scheduled backups, yes or no" "${BACKUP_CRON_ENABLED:-yes}"

validate_hostname "${MAIL_HOSTNAME}" || die "invalid MAIL_HOSTNAME: ${MAIL_HOSTNAME}"
validate_absolute_path "${BACKUP_ROOT}" || die "invalid BACKUP_ROOT: ${BACKUP_ROOT}"
validate_numeric "${BACKUP_RETENTION_DAYS}" || die "invalid BACKUP_RETENTION_DAYS: ${BACKUP_RETENTION_DAYS}"
validate_yes_no "${DR_SITE_ENABLED}" || die "DR_SITE_ENABLED must be yes or no"
validate_yes_no "${DR_HOST_ENABLED}" || die "DR_HOST_ENABLED must be yes or no"
validate_yes_no "${BACKUP_CRON_ENABLED}" || die "BACKUP_CRON_ENABLED must be yes or no"
validate_hostname "${DR_SITE_SERVER_NAME}" || die "invalid DR_SITE_SERVER_NAME: ${DR_SITE_SERVER_NAME}"

backupdr_profile_write_text "${SCOPE_FILE}" "Backup scope for ${MAIL_HOSTNAME}
config paths: ${BACKUP_CONFIG_PATHS}
mail paths: ${BACKUP_MAIL_PATHS}
runtime paths: ${BACKUP_RUNTIME_PATHS}
databases: ${BACKUP_DATABASES}"
backupdr_profile_write_text "${RESTORE_FILE}" "Restore workflow
1. doas ksh scripts/install/install-backup-dr-assets.ksh --apply
2. doas ksh scripts/ops/verify-backup-set.ksh --run-dir <backup-run-dir>
3. doas ksh scripts/ops/run-restore-drill.ksh --archive <archive> --sha256 <sha256-file>
4. review the staged restore under ${RESTORE_STAGING_DIR}
5. only after review, set RESTORE_ALLOW_OVERWRITE=yes and rerun with scripts/ops/restore-mailstack.ksh --apply-files if required"
backupdr_profile_write_text "${DR_SITE_FILE}" "DR site provisioning
DR site enabled: ${DR_SITE_ENABLED}
server name: ${DR_SITE_SERVER_NAME}
Dry run: doas ksh scripts/install/install-dr-site-assets.ksh --dry-run
Apply:   doas ksh scripts/install/install-dr-site-assets.ksh --apply"
backupdr_profile_write_text "${SCHEDULE_FILE}" "Backup schedule provisioning
Scheduled backups enabled: ${BACKUP_CRON_ENABLED}
Dry run: doas ksh scripts/install/install-backup-schedule-assets.ksh --dry-run
Apply:   doas ksh scripts/install/install-backup-schedule-assets.ksh --apply"
backupdr_profile_write_text "${DR_HOST_FILE}" "DR host bootstrap
DR host enabled: ${DR_HOST_ENABLED}
Dry run: doas ksh scripts/install/provision-dr-site-host.ksh --dry-run
Apply:   doas ksh scripts/install/provision-dr-site-host.ksh --apply"
backupdr_profile_write_text "${SUMMARY_FILE}" "Phase 11 backup and disaster recovery summary
mail hostname: ${MAIL_HOSTNAME}
backup root: ${BACKUP_ROOT}
retention days: ${BACKUP_RETENTION_DAYS}
restore staging dir: ${RESTORE_STAGING_DIR}
DR site enabled: ${DR_SITE_ENABLED}
DR site server name: ${DR_SITE_SERVER_NAME}
DR host enabled: ${DR_HOST_ENABLED}
backup cron enabled: ${BACKUP_CRON_ENABLED}
plan directory: ${PLAN_DIR}"
log_info "phase 11 backup and disaster recovery baseline completed"
log_info "generated live plan pack in ${PLAN_DIR}"
