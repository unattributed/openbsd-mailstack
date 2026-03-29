#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
BACKUP_LIB="${PROJECT_ROOT}/scripts/lib/backup-dr.ksh"
. "${BACKUP_LIB}"

RUN_DIR=""
ARCHIVE=""
SHA_FILE=""

usage() {
  cat <<'EOF'
usage: verify-backup-set.ksh --run-dir DIR
   or: verify-backup-set.ksh --archive FILE --sha256 FILE
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    --archive) ARCHIVE="$2"; shift 2 ;;
    --sha256) SHA_FILE="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) print -- "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -n "${RUN_DIR}" ]; then
  ARCHIVE="$(find "${RUN_DIR}" -maxdepth 1 -type f -name '*.tgz' | sort | head -n 1)"
  SHA_FILE="$(find "${RUN_DIR}" -maxdepth 1 -type f -name '*.sha256' | sort | head -n 1)"
fi

[ -n "${ARCHIVE}" ] || die "archive is required"
[ -n "${SHA_FILE}" ] || die "sha256 file is required"
backupdr_verify_archive_hash "${ARCHIVE}" "${SHA_FILE}"
print -- "PASS sha256 verified for ${ARCHIVE}"
