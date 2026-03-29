#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${COMMON_LIB}"

MODE="${1:---dry-run}"
case "${MODE}" in
  --dry-run|--apply) ;;
  *) print -- "usage: $(basename "$0") --dry-run | --apply" >&2; exit 2 ;;
esac

load_project_config
prompt_value "BACKUP_CRON_ENABLED" "Enable scheduled backups, yes or no" "${BACKUP_CRON_ENABLED:-yes}"
prompt_value "BACKUP_CRON_PATCH_ROOT_CRONTAB" "Patch the root crontab automatically, yes or no" "${BACKUP_CRON_PATCH_ROOT_CRONTAB:-no}"
prompt_value "BACKUP_CRON_SNIPPET_PATH" "Enter the backup cron snippet path" "${BACKUP_CRON_SNIPPET_PATH:-/root/.config/openbsd-mailstack/root-cron.backup}"
prompt_value "BACKUP_CRON_LOG_DIR" "Enter the backup cron log directory" "${BACKUP_CRON_LOG_DIR:-/var/log/openbsd-mailstack}"
prompt_value "BACKUP_CRON_ALL_MINUTE" "Enter the unified backup minute" "${BACKUP_CRON_ALL_MINUTE:-55}"
prompt_value "BACKUP_CRON_ALL_HOUR" "Enter the unified backup hour" "${BACKUP_CRON_ALL_HOUR:-2}"

validate_yes_no "${BACKUP_CRON_ENABLED}" || die "BACKUP_CRON_ENABLED must be yes or no"
validate_yes_no "${BACKUP_CRON_PATCH_ROOT_CRONTAB}" || die "BACKUP_CRON_PATCH_ROOT_CRONTAB must be yes or no"
validate_absolute_path "${BACKUP_CRON_SNIPPET_PATH}" || die "invalid BACKUP_CRON_SNIPPET_PATH: ${BACKUP_CRON_SNIPPET_PATH}"
validate_absolute_path "${BACKUP_CRON_LOG_DIR}" || die "invalid BACKUP_CRON_LOG_DIR: ${BACKUP_CRON_LOG_DIR}"
validate_numeric "${BACKUP_CRON_ALL_MINUTE}" || die "invalid BACKUP_CRON_ALL_MINUTE"
validate_numeric "${BACKUP_CRON_ALL_HOUR}" || die "invalid BACKUP_CRON_ALL_HOUR"

[ "${BACKUP_CRON_ENABLED}" = "yes" ] || { print -- "scheduled backups disabled by configuration"; exit 0; }

SNIPPET_CONTENT="# openbsd-mailstack backup and DR schedule
${BACKUP_CRON_ALL_MINUTE} ${BACKUP_CRON_ALL_HOUR} * * * /usr/local/sbin/openbsd-mailstack-backup-all --run >> ${BACKUP_CRON_LOG_DIR}/backup-all.log 2>&1"

if [ "${MODE}" = "--dry-run" ]; then
  print -- "+ would create ${BACKUP_CRON_LOG_DIR}"
  print -- "+ would write ${BACKUP_CRON_SNIPPET_PATH}"
  print -- "${SNIPPET_CONTENT}"
  [ "${BACKUP_CRON_PATCH_ROOT_CRONTAB}" = "yes" ] && print -- "+ would merge the snippet into the root crontab"
  exit 0
fi

[ "$(id -u)" -eq 0 ] || die "this action must run as root"
install -d -m 0755 "${BACKUP_CRON_LOG_DIR}"
install -d -m 0700 "$(dirname -- "${BACKUP_CRON_SNIPPET_PATH}")"
printf '%s
' "${SNIPPET_CONTENT}" > "${BACKUP_CRON_SNIPPET_PATH}"
chmod 0600 "${BACKUP_CRON_SNIPPET_PATH}"

if [ "${BACKUP_CRON_PATCH_ROOT_CRONTAB}" = "yes" ]; then
  _tmp="$(mktemp)"
  crontab -l > "${_tmp}" 2>/dev/null || true
  if ! grep -Fq '/usr/local/sbin/openbsd-mailstack-backup-all --run' "${_tmp}"; then
    printf '
%s
' "${SNIPPET_CONTENT}" >> "${_tmp}"
    crontab "${_tmp}" || die "failed updating root crontab"
  fi
  rm -f "${_tmp}"
fi

print -- "backup schedule assets processed in mode ${MODE}"
