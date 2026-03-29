#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${COMMON_LIB}"

BACKUP_CONFIG_SCRIPT="${PROJECT_ROOT}/scripts/ops/backup-config.ksh"
BACKUP_MARIADB_SCRIPT="${PROJECT_ROOT}/scripts/ops/backup-mariadb.ksh"
BACKUP_MAILSTACK_SCRIPT="${PROJECT_ROOT}/scripts/ops/backup-mailstack.ksh"
PROTECT_SCRIPT="${PROJECT_ROOT}/scripts/ops/protect-backup-set.ksh"
REPLICATE_SCRIPT="${PROJECT_ROOT}/scripts/ops/replicate-backup-offhost.ksh"

MODE="${1:---dry-run}"
case "${MODE}" in
  --dry-run|--run) ;;
  *) print -- "usage: $(basename "$0") --dry-run | --run" >&2; exit 2 ;;
esac

load_project_config
prompt_value "BACKUP_PROTECT_AFTER_RUN" "Protect backup archives after the unified run, yes or no" "${BACKUP_PROTECT_AFTER_RUN:-yes}"
prompt_value "BACKUP_REPLICATE_AFTER_BACKUP" "Replicate the mailstack archive off-host after the unified run, yes or no" "${BACKUP_REPLICATE_AFTER_BACKUP:-no}"
validate_yes_no "${BACKUP_PROTECT_AFTER_RUN}" || die "BACKUP_PROTECT_AFTER_RUN must be yes or no"
validate_yes_no "${BACKUP_REPLICATE_AFTER_BACKUP}" || die "BACKUP_REPLICATE_AFTER_BACKUP must be yes or no"

run_backup_script() {
  _script="$1"
  if [ "${MODE}" = "--dry-run" ]; then
    ksh "${_script}" --dry-run
  else
    ksh "${_script}" --run
  fi
}

latest_run_dir() {
  _base="$1"
  if [ -L "${_base}/latest" ]; then
    _resolved="$(cd "${_base}" && readlink latest)"
    [ -n "${_resolved}" ] && print -- "${_base}/${_resolved}" && return 0
  fi
  ls -1dt "${_base}"/* 2>/dev/null | head -n 1 || true
}

run_backup_script "${BACKUP_CONFIG_SCRIPT}"
run_backup_script "${BACKUP_MARIADB_SCRIPT}"
run_backup_script "${BACKUP_MAILSTACK_SCRIPT}"

[ "${MODE}" = "--run" ] || exit 0

if [ "${BACKUP_PROTECT_AFTER_RUN}" = "yes" ]; then
  for _base in /var/backups/openbsd-mailstack/config /var/backups/openbsd-mailstack/mariadb /var/backups/openbsd-mailstack/mailstack; do
    _run_dir="$(latest_run_dir "${_base}")"
    [ -n "${_run_dir}" ] || continue
    ksh "${PROTECT_SCRIPT}" --run --run-dir "${_run_dir}"
  done
fi

if [ "${BACKUP_REPLICATE_AFTER_BACKUP}" = "yes" ]; then
  _mailstack_run="$(latest_run_dir "/var/backups/openbsd-mailstack/mailstack")"
  [ -n "${_mailstack_run}" ] || die "mailstack run dir not found for replication"
  ksh "${REPLICATE_SCRIPT}" --apply --run-dir "${_mailstack_run}"
fi

print -- "unified backup run completed"
