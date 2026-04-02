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

advanced_work_root() {
  : "${OPENBSD_MAILSTACK_ADVANCED_RENDER_ROOT:=${PROJECT_ROOT}/.work/advanced/rootfs}"
  print -- "$(dirname -- "${OPENBSD_MAILSTACK_ADVANCED_RENDER_ROOT}")"
}

advanced_profile_phase_dir() {
  _phase_num="$1"
  _phase_id="$(printf '%02d' "${_phase_num}")"
  print -- "$(advanced_work_root)/phase-${_phase_id}"
}

advanced_readiness_dir() {
  print -- "$(advanced_work_root)/readiness"
}

advanced_profile_write_text() {
  _dst="$1"
  shift
  ensure_directory "$(dirname -- "${_dst}")"
  cat > "${_dst}" <<EOF2
$*
EOF2
}

advanced_profile_check_no_placeholders() {
  _file="$1"
  [ -f "${_file}" ] || return 1
  if grep -Eq '__[A-Z0-9_]+__' "${_file}"; then
    return 1
  fi
  return 0
}
