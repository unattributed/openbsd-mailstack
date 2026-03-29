#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${COMMON_LIB}"

MODE="--dry-run"
RUN_DIR=""
ARCHIVE=""
SHA_FILE=""

usage() {
  cat <<'EOF'
usage: protect-backup-set.ksh [--dry-run|--run] (--run-dir DIR | --archive FILE [--sha256 FILE])
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run|--run) MODE="$1"; shift ;;
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    --archive) ARCHIVE="$2"; shift 2 ;;
    --sha256) SHA_FILE="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) print -- "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

load_project_config
prompt_value "BACKUP_ENABLE_SIGNIFY" "Enable signify signing, yes or no" "${BACKUP_ENABLE_SIGNIFY:-no}"
prompt_value "BACKUP_SIGNIFY_SECRET_KEY" "Enter the signify secret key path" "${BACKUP_SIGNIFY_SECRET_KEY:-/root/.signify/openbsd-mailstack-backup.sec}"
prompt_value "BACKUP_ENABLE_GPG" "Enable GPG encryption, yes or no" "${BACKUP_ENABLE_GPG:-no}"
prompt_value "BACKUP_GPG_RECIPIENT" "Enter the GPG recipient, leave empty if disabled" "${BACKUP_GPG_RECIPIENT:-}"

validate_yes_no "${BACKUP_ENABLE_SIGNIFY}" || die "BACKUP_ENABLE_SIGNIFY must be yes or no"
validate_yes_no "${BACKUP_ENABLE_GPG}" || die "BACKUP_ENABLE_GPG must be yes or no"

if [ -n "${RUN_DIR}" ]; then
  [ -d "${RUN_DIR}" ] || die "run dir not found: ${RUN_DIR}"
  [ -n "${ARCHIVE}" ] || ARCHIVE="$(ls -1 "${RUN_DIR}"/*.tgz 2>/dev/null | head -n 1 || true)"
  [ -n "${SHA_FILE}" ] || SHA_FILE="$(ls -1 "${RUN_DIR}"/*.sha256 2>/dev/null | head -n 1 || true)"
fi

[ -n "${ARCHIVE}" ] || die "an archive is required"
[ -f "${ARCHIVE}" ] || die "archive not found: ${ARCHIVE}"
[ -n "${SHA_FILE}" ] || SHA_FILE="${ARCHIVE}.sha256"

if [ "${MODE}" = "--dry-run" ]; then
  print -- "+ would protect ${ARCHIVE}"
  [ "${BACKUP_ENABLE_SIGNIFY}" = "yes" ] && print -- "+ would sign archive with ${BACKUP_SIGNIFY_SECRET_KEY}"
  [ "${BACKUP_ENABLE_GPG}" = "yes" ] && print -- "+ would encrypt archive for ${BACKUP_GPG_RECIPIENT}"
  exit 0
fi

[ "$(id -u)" -eq 0 ] || die "this action must run as root"

if [ "${BACKUP_ENABLE_SIGNIFY}" = "yes" ]; then
  command_exists signify || die "signify is required when BACKUP_ENABLE_SIGNIFY=yes"
  [ -r "${BACKUP_SIGNIFY_SECRET_KEY}" ] || die "signify secret key not readable: ${BACKUP_SIGNIFY_SECRET_KEY}"
  signify -S -s "${BACKUP_SIGNIFY_SECRET_KEY}" -m "${ARCHIVE}" -x "${ARCHIVE}.sig" || die "failed signing archive ${ARCHIVE}"
  if [ -f "${SHA_FILE}" ]; then
    signify -S -s "${BACKUP_SIGNIFY_SECRET_KEY}" -m "${SHA_FILE}" -x "${SHA_FILE}.sig" || die "failed signing sha256 file ${SHA_FILE}"
  fi
fi

if [ "${BACKUP_ENABLE_GPG}" = "yes" ]; then
  command_exists gpg || die "gpg is required when BACKUP_ENABLE_GPG=yes"
  [ -n "${BACKUP_GPG_RECIPIENT}" ] || die "BACKUP_GPG_RECIPIENT is required when GPG encryption is enabled"
  gpg --batch --yes --output "${ARCHIVE}.gpg" --encrypt --recipient "${BACKUP_GPG_RECIPIENT}" "${ARCHIVE}" || die "failed encrypting ${ARCHIVE}"
  if [ -f "${SHA_FILE}" ]; then
    gpg --batch --yes --output "${SHA_FILE}.gpg" --encrypt --recipient "${BACKUP_GPG_RECIPIENT}" "${SHA_FILE}" || die "failed encrypting ${SHA_FILE}"
  fi
fi

print -- "protected backup set for ${ARCHIVE}"
