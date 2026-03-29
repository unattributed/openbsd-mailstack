#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
BACKUP_LIB="${PROJECT_ROOT}/scripts/lib/backup-dr.ksh"
. "${BACKUP_LIB}"

MODE="${1:---dry-run}"
case "${MODE}" in
  --dry-run|--run) ;;
  *) print -- "usage: $(basename "$0") --dry-run | --run" >&2; exit 2 ;;
esac

load_project_config
prompt_value "BACKUP_ROOT" "Enter the backup root directory" "${BACKUP_ROOT:-/var/backups/openbsd-mailstack}"
prompt_value "BACKUP_RETENTION_DAYS" "Enter backup retention in days" "${BACKUP_RETENTION_DAYS:-30}"
prompt_value "BACKUP_CONFIG_PATHS" "Enter space separated config backup paths" "${BACKUP_CONFIG_PATHS:-/etc /etc/ssl /etc/ssl/private /var/www /var/db/acme}"
prompt_value "BACKUP_MAIL_PATHS" "Enter space separated mail storage paths" "${BACKUP_MAIL_PATHS:-/var/vmail}"
prompt_value "BACKUP_RUNTIME_PATHS" "Enter space separated runtime paths" "${BACKUP_RUNTIME_PATHS:-/var/spool/postfix /var/db/redis /var/db/clamav /var/log}"

validate_absolute_path "${BACKUP_ROOT}" || die "invalid BACKUP_ROOT: ${BACKUP_ROOT}"
validate_numeric "${BACKUP_RETENTION_DAYS}" || die "invalid BACKUP_RETENTION_DAYS: ${BACKUP_RETENTION_DAYS}"

RUN_ID="$(backupdr_now)"
BASE_DIR="${BACKUP_ROOT}/mailstack"
RUN_DIR="${BASE_DIR}/${RUN_ID}"
ARCHIVE="${RUN_DIR}/mailstack-${RUN_ID}.tgz"
SHA_FILE="${RUN_DIR}/mailstack-${RUN_ID}.sha256"
SUMMARY="${RUN_DIR}/summary.txt"

if [ "${MODE}" = "--dry-run" ]; then
  print -- "+ would create ${RUN_DIR}"
  for _path in ${BACKUP_CONFIG_PATHS} ${BACKUP_MAIL_PATHS} ${BACKUP_RUNTIME_PATHS}; do
    print -- "+ would capture ${_path}"
  done
  exit 0
fi

backupdr_require_root
backupdr_ensure_run_dirs "${RUN_DIR}"
for _path in ${BACKUP_CONFIG_PATHS} ${BACKUP_MAIL_PATHS} ${BACKUP_RUNTIME_PATHS}; do
  backupdr_capture_path "${_path}" "${RUN_DIR}/payload/rootfs"
done
uname -a > "${RUN_DIR}/metadata/uname.txt" 2>/dev/null || true
rcctl ls on > "${RUN_DIR}/metadata/rcctl-ls-on.txt" 2>/dev/null || true
pkg_info -mz > "${RUN_DIR}/metadata/pkg-info-mz.txt" 2>/dev/null || true
crontab -l > "${RUN_DIR}/metadata/root-crontab.txt" 2>/dev/null || true
print -- "kind=mailstack" > "${RUN_DIR}/metadata/kind.txt"
print -- "run_id=${RUN_ID}" > "${RUN_DIR}/metadata/run-id.txt"
print -- "config_paths=${BACKUP_CONFIG_PATHS}" > "${RUN_DIR}/metadata/config-paths.txt"
print -- "mail_paths=${BACKUP_MAIL_PATHS}" > "${RUN_DIR}/metadata/mail-paths.txt"
print -- "runtime_paths=${BACKUP_RUNTIME_PATHS}" > "${RUN_DIR}/metadata/runtime-paths.txt"
backupdr_write_manifest "${RUN_DIR}"
backupdr_create_archive "${RUN_DIR}" "${ARCHIVE}"
backupdr_write_sha256 "${ARCHIVE}" "${SHA_FILE}"
cat > "${SUMMARY}" <<EOF
openbsd-mailstack mailstack backup
run_id: ${RUN_ID}
archive: ${ARCHIVE}
sha256: ${SHA_FILE}
config paths: ${BACKUP_CONFIG_PATHS}
mail paths: ${BACKUP_MAIL_PATHS}
runtime paths: ${BACKUP_RUNTIME_PATHS}
EOF
backupdr_prune_old_runs "${BASE_DIR}" "${BACKUP_RETENTION_DAYS}"
backupdr_update_latest_link "${BASE_DIR}" "${RUN_ID}"
print -- "backup written to ${RUN_DIR}"
