#!/bin/ksh
set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing common library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

backupdr_now() {
  date -u "+%Y%m%dT%H%M%SZ"
}

backupdr_require_root() {
  [ "$(id -u)" -eq 0 ] || die "this action must run as root"
}

backupdr_find_dump_command() {
  if [ -n "${BACKUP_DB_DUMP_COMMAND:-}" ]; then
    print -- "${BACKUP_DB_DUMP_COMMAND}"
    return 0
  fi
  for _cmd in mariadb-dump mysqldump; do
    if command_exists "${_cmd}"; then
      print -- "${_cmd}"
      return 0
    fi
  done
  return 1
}

backupdr_ensure_run_dirs() {
  _run_dir="$1"
  ensure_directory "${_run_dir}"
  ensure_directory "${_run_dir}/payload"
  ensure_directory "${_run_dir}/payload/rootfs"
  ensure_directory "${_run_dir}/payload/db"
  ensure_directory "${_run_dir}/metadata"
}

backupdr_capture_path() {
  _src="$1"
  _dst_root="$2"
  if [ ! -e "${_src}" ]; then
    log_warn "backup source missing, skipped: ${_src}"
    return 0
  fi
  ensure_directory "${_dst_root}"
  (cd / && tar -cf - "${_src#/}") | (cd "${_dst_root}" && tar -xpf -) || die "failed to capture ${_src}"
}

backupdr_write_manifest() {
  _run_dir="$1"
  (cd "${_run_dir}" && find payload metadata -print | sort) > "${_run_dir}/manifest.txt" || die "failed to write manifest"
}

backupdr_write_sha256() {
  _archive="$1"
  _sha_file="$2"
  sha256 "${_archive}" | awk '{print $1}' > "${_sha_file}" || die "failed to write sha256 for ${_archive}"
}

backupdr_create_archive() {
  _run_dir="$1"
  _archive="$2"
  (cd "${_run_dir}" && tar -czf "${_archive}" payload metadata manifest.txt) || die "failed to create archive ${_archive}"
}

backupdr_prune_old_runs() {
  _base_dir="$1"
  _keep_days="$2"
  [ -d "${_base_dir}" ] || return 0
  find "${_base_dir}" -mindepth 1 -maxdepth 1 -type d -mtime +"${_keep_days}" -exec rm -rf {} + 2>/dev/null || true
}

backupdr_update_latest_link() {
  _base_dir="$1"
  _run_dir_name="$2"
  ln -sfn "${_run_dir_name}" "${_base_dir}/latest" || die "failed to update latest symlink in ${_base_dir}"
}

backupdr_verify_archive_hash() {
  _archive="$1"
  _sha_file="$2"
  [ -f "${_archive}" ] || die "archive not found: ${_archive}"
  [ -f "${_sha_file}" ] || die "sha256 file not found: ${_sha_file}"
  _expected="$(awk 'NR==1 {print $1}' "${_sha_file}")"
  _actual="$(sha256 "${_archive}" | awk '{print $1}')"
  [ -n "${_expected}" ] || die "expected hash is empty in ${_sha_file}"
  [ "${_expected}" = "${_actual}" ] || die "archive hash mismatch for ${_archive}"
}
