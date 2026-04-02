#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing shared library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

FAIL=0
WARN=0
PASS=0

pass() { print -- "[$(timestamp)] PASS  $*"; PASS=$((PASS + 1)); }
warn() { print -- "[$(timestamp)] WARN  $*"; WARN=$((WARN + 1)); }
fail() { print -- "[$(timestamp)] FAIL  $*"; FAIL=$((FAIL + 1)); }

check_file() {
  _path="$1"
  _label="$2"
  if [ -f "${_path}" ]; then
    pass "${_label}: ${_path}"
  else
    fail "${_label} is missing: ${_path}"
  fi
}

check_phase_coverage() {
  _phase=0
  while [ "${_phase}" -le 17 ]; do
    _id="$(printf '%02d' "${_phase}")"
    check_file "${PROJECT_ROOT}/scripts/phases/phase-${_id}-apply.ksh" "phase ${_id} apply script present"
    check_file "${PROJECT_ROOT}/scripts/phases/phase-${_id}-verify.ksh" "phase ${_id} verify script present"
    _phase=$(( _phase + 1 ))
  done
}

check_ksh_syntax() {
  if ! command_exists ksh; then
    warn "ksh not available, skipping shell syntax validation"
    return 0
  fi

  while IFS= read -r _script || [ -n "${_script}" ]; do
    [ -n "${_script}" ] || continue
    if ksh -n "${_script}" >/dev/null 2>&1; then
      pass "ksh syntax ok: ${_script#${PROJECT_ROOT}/}"
    else
      fail "ksh syntax failed: ${_script#${PROJECT_ROOT}/}"
    fi
  done <<EOF2
$(find "${PROJECT_ROOT}/scripts" "${PROJECT_ROOT}/maint" -type f \( -name '*.ksh' -o -name '*.sh' \) | sort)
EOF2
}

check_python_syntax() {
  if command_exists python3; then
    _python_bin="$(command -v python3)"
  elif command_exists python; then
    _python_bin="$(command -v python)"
  else
    warn "python interpreter not available, skipping python syntax validation"
    return 0
  fi

  while IFS= read -r _script || [ -n "${_script}" ]; do
    [ -n "${_script}" ] || continue
    if "${_python_bin}" -m py_compile "${_script}" >/dev/null 2>&1; then
      pass "python syntax ok: ${_script#${PROJECT_ROOT}/}"
    else
      fail "python syntax failed: ${_script#${PROJECT_ROOT}/}"
    fi
  done <<EOF2
$(find "${PROJECT_ROOT}/scripts" "${PROJECT_ROOT}/maint" -type f -name '*.py' | sort)
EOF2
}

check_unresolved_placeholders_in_concrete_examples() {
  _found=0
  while IFS= read -r _path; do
    [ -n "${_path}" ] || continue
    if grep -Eq '__[A-Z0-9_][A-Z0-9_]*__' "${_path}"; then
      fail "unresolved placeholder found in concrete generated example: ${_path#${PROJECT_ROOT}/}"
      _found=1
    fi
  done <<EOF2
$(find "${PROJECT_ROOT}/services/generated/rootfs" -type f \
  ! -name '*.tmpl' \
  ! -name '*.template' \
  ! -name '*.example' \
  ! -name '*.example.*' | sort)
EOF2

  [ "${_found}" -eq 1 ] || pass "no unresolved placeholders found in concrete generated examples"
}

check_render_root_defaults() {
  _core_root="$(core_runtime_render_root)"
  case "${_core_root}" in
    "${PROJECT_ROOT}/.work/"*|"${PROJECT_ROOT}/.work")
      pass "core runtime render root defaults to gitignored work area: ${_core_root}"
      ;;
    *)
      fail "core runtime render root is not in the gitignored work area: ${_core_root}"
      ;;
  esac

  if grep -Eq '^\.work/$' "${PROJECT_ROOT}/.gitignore"; then
    pass ".work/ is ignored by git"
  else
    fail ".work/ is not ignored by git"
  fi
}

print_summary() {
  print
  print -- "Repository semantic validation summary"
  print -- "  PASS count : ${PASS}"
  print -- "  WARN count : ${WARN}"
  print -- "  FAIL count : ${FAIL}"
  print
}

main() {
  check_phase_coverage
  check_render_root_defaults
  check_ksh_syntax
  check_python_syntax
  check_unresolved_placeholders_in_concrete_examples
  print_summary
  [ "${FAIL}" -eq 0 ]
}

main "$@"
