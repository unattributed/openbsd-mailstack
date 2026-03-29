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
prompt_value "BACKUP_DATABASES" "Enter space separated databases to dump" "${BACKUP_DATABASES:-mysql postfixadmin roundcube}"
prompt_value "BACKUP_DB_CREDENTIAL_FILE" "Enter the MariaDB defaults file path" "${BACKUP_DB_CREDENTIAL_FILE:-/root/.my.cnf}"

validate_absolute_path "${BACKUP_ROOT}" || die "invalid BACKUP_ROOT: ${BACKUP_ROOT}"
validate_numeric "${BACKUP_RETENTION_DAYS}" || die "invalid BACKUP_RETENTION_DAYS: ${BACKUP_RETENTION_DAYS}"
validate_absolute_path "${BACKUP_DB_CREDENTIAL_FILE}" || die "invalid BACKUP_DB_CREDENTIAL_FILE: ${BACKUP_DB_CREDENTIAL_FILE}"
[ -n "${BACKUP_DATABASES}" ] || die "BACKUP_DATABASES is required"

RUN_ID="$(backupdr_now)"
BASE_DIR="${BACKUP_ROOT}/mariadb"
RUN_DIR="${BASE_DIR}/${RUN_ID}"
ARCHIVE="${RUN_DIR}/mariadb-${RUN_ID}.tgz"
SHA_FILE="${RUN_DIR}/mariadb-${RUN_ID}.sha256"
SUMMARY="${RUN_DIR}/summary.txt"
DUMP_CMD="$(backupdr_find_dump_command)" || die "mysqldump or mariadb-dump is required"

if [ "${MODE}" = "--dry-run" ]; then
  print -- "+ would create ${RUN_DIR}"
  print -- "+ would use ${DUMP_CMD} with defaults file ${BACKUP_DB_CREDENTIAL_FILE}"
  for _db in ${BACKUP_DATABASES}; do
    print -- "+ would dump ${_db}"
  done
  exit 0
fi

backupdr_require_root
[ -r "${BACKUP_DB_CREDENTIAL_FILE}" ] || die "MariaDB defaults file is not readable: ${BACKUP_DB_CREDENTIAL_FILE}"
backupdr_ensure_run_dirs "${RUN_DIR}"
for _db in ${BACKUP_DATABASES}; do
  _out="${RUN_DIR}/payload/db/${_db}.sql"
  "${DUMP_CMD}" --defaults-file="${BACKUP_DB_CREDENTIAL_FILE}" --databases "${_db}" > "${_out}" || die "failed dumping database ${_db}"
  gzip -f "${_out}" || die "failed compressing database dump ${_db}"
done
print -- "kind=mariadb" > "${RUN_DIR}/metadata/kind.txt"
print -- "run_id=${RUN_ID}" > "${RUN_DIR}/metadata/run-id.txt"
print -- "databases=${BACKUP_DATABASES}" > "${RUN_DIR}/metadata/databases.txt"
backupdr_write_manifest "${RUN_DIR}"
backupdr_create_archive "${RUN_DIR}" "${ARCHIVE}"
backupdr_write_sha256 "${ARCHIVE}" "${SHA_FILE}"
cat > "${SUMMARY}" <<EOF
openbsd-mailstack mariadb backup
run_id: ${RUN_ID}
archive: ${ARCHIVE}
sha256: ${SHA_FILE}
databases: ${BACKUP_DATABASES}
dump_command: ${DUMP_CMD}
EOF
backupdr_prune_old_runs "${BASE_DIR}" "${BACKUP_RETENTION_DAYS}"
backupdr_update_latest_link "${BASE_DIR}" "${RUN_ID}"
print -- "backup written to ${RUN_DIR}"
