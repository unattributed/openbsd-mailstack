#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${COMMON_LIB}"

MODE="--dry-run"
RUN_DIR=""

usage() {
  cat <<'EOF'
usage: replicate-backup-offhost.ksh [--dry-run|--apply] --run-dir DIR
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run|--apply) MODE="$1"; shift ;;
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) print -- "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "${RUN_DIR}" ] || die "--run-dir is required"
[ -d "${RUN_DIR}" ] || die "run directory not found: ${RUN_DIR}"

load_project_config
prompt_value "BACKUP_OFFSITE_MODE" "Enter the off-host transfer mode" "${BACKUP_OFFSITE_MODE:-ssh}"
prompt_value "BACKUP_OFFSITE_TARGET" "Enter the off-host target" "${BACKUP_OFFSITE_TARGET:-backup@example.net:/srv/openbsd-mailstack}"
prompt_value "BACKUP_OFFSITE_SSH_KEY" "Enter the SSH key path" "${BACKUP_OFFSITE_SSH_KEY:-/root/.ssh/id_ed25519}"

validate_mode_word "${BACKUP_OFFSITE_MODE}" || die "invalid BACKUP_OFFSITE_MODE: ${BACKUP_OFFSITE_MODE}"
[ -n "${BACKUP_OFFSITE_TARGET}" ] || die "BACKUP_OFFSITE_TARGET is required"

FILES="$(find "${RUN_DIR}" -maxdepth 1 -type f \( -name '*.tgz' -o -name '*.sha256' -o -name 'manifest.txt' -o -name 'summary.txt' \) | sort | tr '
' ' ')"
[ -n "${FILES}" ] || die "no backup artifacts found under ${RUN_DIR}"

case "${BACKUP_OFFSITE_MODE}" in
  ssh|scp)
    for _file in ${FILES}; do
      if [ "${MODE}" = "--dry-run" ]; then
        print -- "+ scp -i ${BACKUP_OFFSITE_SSH_KEY} ${_file} ${BACKUP_OFFSITE_TARGET}"
      else
        scp -i "${BACKUP_OFFSITE_SSH_KEY}" "${_file}" "${BACKUP_OFFSITE_TARGET}" || die "failed copying ${_file}"
      fi
    done
    ;;
  rsync)
    if [ "${MODE}" = "--dry-run" ]; then
      print -- "+ rsync -av -e 'ssh -i ${BACKUP_OFFSITE_SSH_KEY}' ${RUN_DIR}/ ${BACKUP_OFFSITE_TARGET}/"
    else
      rsync -av -e "ssh -i ${BACKUP_OFFSITE_SSH_KEY}" "${RUN_DIR}/" "${BACKUP_OFFSITE_TARGET}/" || die "rsync failed"
    fi
    ;;
  *) die "unsupported BACKUP_OFFSITE_MODE: ${BACKUP_OFFSITE_MODE}" ;;
esac

print -- "off-host replication flow completed in mode ${MODE}"
