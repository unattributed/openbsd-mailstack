#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${COMMON_LIB}"
RESTORE_SCRIPT="${PROJECT_ROOT}/scripts/ops/restore-mailstack.ksh"
VERIFY_SCRIPT="${PROJECT_ROOT}/scripts/ops/verify-backup-set.ksh"

ARCHIVE=""
SHA_FILE=""
STAGE_DIR=""

usage() {
  cat <<'EOF'
usage: run-restore-drill.ksh --archive FILE [--sha256 FILE] [--stage-dir DIR]
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --archive) ARCHIVE="$2"; shift 2 ;;
    --sha256) SHA_FILE="$2"; shift 2 ;;
    --stage-dir) STAGE_DIR="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) print -- "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "${ARCHIVE}" ] || die "--archive is required"

if [ -n "${SHA_FILE}" ]; then
  ksh "${VERIFY_SCRIPT}" --archive "${ARCHIVE}" --sha256 "${SHA_FILE}"
fi

if [ -n "${STAGE_DIR}" ] && [ -n "${SHA_FILE}" ]; then
  ksh "${RESTORE_SCRIPT}" --archive "${ARCHIVE}" --stage-dir "${STAGE_DIR}" --sha256 "${SHA_FILE}"
elif [ -n "${STAGE_DIR}" ]; then
  ksh "${RESTORE_SCRIPT}" --archive "${ARCHIVE}" --stage-dir "${STAGE_DIR}"
elif [ -n "${SHA_FILE}" ]; then
  ksh "${RESTORE_SCRIPT}" --archive "${ARCHIVE}" --sha256 "${SHA_FILE}"
else
  ksh "${RESTORE_SCRIPT}" --archive "${ARCHIVE}"
fi

print -- "restore drill completed in staged mode"
