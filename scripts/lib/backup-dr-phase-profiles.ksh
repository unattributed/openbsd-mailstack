#!/bin/ksh
set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
BACKUP_DR_LIB="${PROJECT_ROOT}/scripts/lib/backup-dr.ksh"

[ -f "${BACKUP_DR_LIB}" ] || {
  print -- "ERROR missing backup DR library: ${BACKUP_DR_LIB}" >&2
  exit 1
}

. "${BACKUP_DR_LIB}"

backupdr_profile_phase_dir() {
  _phase_num="$1"
  _phase_id="$(printf '%02d' "${_phase_num}")"
  print -- "$(backupdr_phase_plan_dir "${_phase_id}")"
}

backupdr_profile_write_text() {
  _dst="$1"
  shift
  ensure_directory "$(dirname -- "${_dst}")"
  cat > "${_dst}" <<EOF
$*
EOF
}

backupdr_profile_check_no_placeholders() {
  _file="$1"
  [ -f "${_file}" ] || return 1
  if grep -Eq '__[A-Z0-9_]+__' "${_file}"; then
    return 1
  fi
  return 0
}

backupdr_profile_validate_files() {
  _missing=0
  for _file in "$@"; do
    if [ -f "${_file}" ]; then
      print -- "PASS found ${_file}"
    else
      print -- "FAIL missing ${_file}"
      _missing=$(( _missing + 1 ))
    fi
  done
  [ "${_missing}" -eq 0 ]
}
