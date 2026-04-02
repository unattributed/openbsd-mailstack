#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
BACKUP_LIB="${PROJECT_ROOT}/scripts/lib/backup-dr.ksh"
. "${BACKUP_LIB}"

OUTPUT_MODE="--write"

usage() {
  cat <<'EOF'
usage: backup-dr-readiness-report.ksh [--stdout|--write]
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --stdout|--write) OUTPUT_MODE="$1"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) print -- "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

load_project_config
: "${MAIL_HOSTNAME:=mail.example.com}"
: "${BACKUP_ROOT:=/var/backups/openbsd-mailstack}"
: "${RESTORE_STAGING_DIR:=/var/restore/openbsd-mailstack}"
: "${BACKUP_OFFSITE_MODE:=ssh}"
: "${BACKUP_OFFSITE_TARGET:=backup@example.net:/srv/openbsd-mailstack}"
: "${DR_SITE_SERVER_NAME:=dr.example.com}"
: "${DR_HOST_ENABLED:=yes}"

_plan_root="$(backupdr_plan_root)"
_report_path="$(backupdr_readiness_report_path)"
_phase11_dir="$(backupdr_phase_plan_dir 11)"
_phase12_dir="$(backupdr_phase_plan_dir 12)"
_phase13_dir="$(backupdr_phase_plan_dir 13)"

_helpers="install-backup-dr-assets.ksh install-dr-site-assets.ksh install-backup-schedule-assets.ksh provision-dr-site-host.ksh"
_ops="backup-config.ksh backup-mariadb.ksh backup-mailstack.ksh backup-all.ksh protect-backup-set.ksh verify-backup-set.ksh restore-mailstack.ksh run-restore-drill.ksh replicate-backup-offhost.ksh"

_tmp="$(mktemp /tmp/openbsd-mailstack-backupdr-readiness.XXXXXX)"
{
  print -- "Backup and DR readiness report"
  print -- "mail hostname: ${MAIL_HOSTNAME}"
  print -- "backup root: ${BACKUP_ROOT}"
  print -- "restore staging dir: ${RESTORE_STAGING_DIR}"
  print -- "offhost mode: ${BACKUP_OFFSITE_MODE}"
  print -- "offhost target: ${BACKUP_OFFSITE_TARGET}"
  print -- "DR site server name: ${DR_SITE_SERVER_NAME}"
  print -- "DR host enabled: ${DR_HOST_ENABLED}"
  print -- "plan root: ${_plan_root}"
  print -- ""
  print -- "Phase plan directories"
  for _dir in "${_phase11_dir}" "${_phase12_dir}" "${_phase13_dir}"; do
    if [ -d "${_dir}" ]; then
      print -- "- present: ${_dir}"
    else
      print -- "- missing: ${_dir}"
    fi
  done
  print -- ""
  print -- "Install helpers"
  for _helper in ${_helpers}; do
    _path="${PROJECT_ROOT}/scripts/install/${_helper}"
    if [ -f "${_path}" ]; then
      print -- "- present: ${_path}"
    else
      print -- "- missing: ${_path}"
    fi
  done
  print -- ""
  print -- "Runtime helpers"
  for _script in ${_ops}; do
    _path="${PROJECT_ROOT}/scripts/ops/${_script}"
    if [ -f "${_path}" ]; then
      print -- "- present: ${_path}"
    else
      print -- "- missing: ${_path}"
    fi
  done
} > "${_tmp}"

if [ "${OUTPUT_MODE}" = "--stdout" ]; then
  cat "${_tmp}"
else
  ensure_directory "$(dirname -- "${_report_path}")"
  install -m 0644 "${_tmp}" "${_report_path}"
  print -- "wrote ${_report_path}"
fi
rm -f "${_tmp}"
