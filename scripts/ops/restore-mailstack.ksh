#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
BACKUP_LIB="${PROJECT_ROOT}/scripts/lib/backup-dr.ksh"
. "${BACKUP_LIB}"

ARCHIVE=""
SHA_FILE=""
STAGE_DIR=""
TARGET_ROOT="/"
MODE="staged"
APPLY_DATABASE="no"

usage() {
  cat <<'EOF'
usage: restore-mailstack.ksh --archive FILE [options]

Options:
  --sha256 FILE         Verify the archive against FILE before extraction.
  --stage-dir DIR       Extraction directory. Defaults to RESTORE_STAGING_DIR/run-id.
  --target-root DIR     Live restore target root. Defaults to /.
  --staged              Extract only. This is the default.
  --apply-files         Copy payload/rootfs into the target root.
  --apply-database      Import payload/db/*.sql.gz after extraction.
  --help                Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --archive) ARCHIVE="$2"; shift 2 ;;
    --sha256) SHA_FILE="$2"; shift 2 ;;
    --stage-dir) STAGE_DIR="$2"; shift 2 ;;
    --target-root) TARGET_ROOT="$2"; shift 2 ;;
    --staged) MODE="staged"; shift ;;
    --apply-files) MODE="apply"; shift ;;
    --apply-database) APPLY_DATABASE="yes"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) print -- "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "${ARCHIVE}" ] || die "--archive is required"
[ -f "${ARCHIVE}" ] || die "archive not found: ${ARCHIVE}"

load_project_config
prompt_value "RESTORE_STAGING_DIR" "Enter the restore staging directory" "${RESTORE_STAGING_DIR:-/var/restore/openbsd-mailstack}"
prompt_value "RESTORE_ALLOW_OVERWRITE" "Allow direct overwrite, yes or no" "${RESTORE_ALLOW_OVERWRITE:-no}"
prompt_value "BACKUP_DB_CREDENTIAL_FILE" "Enter the MariaDB defaults file path" "${BACKUP_DB_CREDENTIAL_FILE:-/root/.my.cnf}"

validate_absolute_path "${RESTORE_STAGING_DIR}" || die "invalid RESTORE_STAGING_DIR: ${RESTORE_STAGING_DIR}"
validate_yes_no "${RESTORE_ALLOW_OVERWRITE}" || die "RESTORE_ALLOW_OVERWRITE must be yes or no"
validate_absolute_path "${TARGET_ROOT}" || die "invalid TARGET_ROOT: ${TARGET_ROOT}"

RUN_ID="$(backupdr_now)"
[ -n "${STAGE_DIR}" ] || STAGE_DIR="${RESTORE_STAGING_DIR}/${RUN_ID}"
ensure_directory "${STAGE_DIR}"

if [ -n "${SHA_FILE}" ]; then
  backupdr_verify_archive_hash "${ARCHIVE}" "${SHA_FILE}"
fi

tar -xzf "${ARCHIVE}" -C "${STAGE_DIR}" || die "failed extracting ${ARCHIVE}"
cat > "${STAGE_DIR}/restore-summary.txt" <<EOF
openbsd-mailstack restore
archive: ${ARCHIVE}
stage_dir: ${STAGE_DIR}
mode: ${MODE}
apply_database: ${APPLY_DATABASE}
target_root: ${TARGET_ROOT}
EOF

if [ "${MODE}" = "staged" ]; then
  print -- "staged extraction complete at ${STAGE_DIR}"
  print -- "no live restore was performed"
  exit 0
fi

[ "${RESTORE_ALLOW_OVERWRITE}" = "yes" ] || die "RESTORE_ALLOW_OVERWRITE must be yes for --apply-files"
backupdr_require_root
[ -d "${STAGE_DIR}/payload/rootfs" ] || die "expected payload/rootfs under ${STAGE_DIR}"
(cd "${STAGE_DIR}/payload/rootfs" && tar -cf - .) | (cd "${TARGET_ROOT}" && tar -xpf -) || die "failed copying payload/rootfs into ${TARGET_ROOT}"

if [ "${APPLY_DATABASE}" = "yes" ] && [ -d "${STAGE_DIR}/payload/db" ]; then
  DUMP_IMPORT_CMD="$(command -v mariadb 2>/dev/null || command -v mysql 2>/dev/null || true)"
  [ -n "${DUMP_IMPORT_CMD}" ] || die "mariadb or mysql client is required for database import"
  [ -r "${BACKUP_DB_CREDENTIAL_FILE}" ] || die "MariaDB defaults file is not readable: ${BACKUP_DB_CREDENTIAL_FILE}"
  for _dump in "${STAGE_DIR}"/payload/db/*.sql.gz; do
    [ -f "${_dump}" ] || continue
    gzip -dc "${_dump}" | "${DUMP_IMPORT_CMD}" --defaults-file="${BACKUP_DB_CREDENTIAL_FILE}" || die "failed importing ${_dump}"
  done
fi

print -- "live restore completed from ${ARCHIVE}"
