#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing shared library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

PHASE_START=0
PHASE_END=10
MODE="apply-and-verify"

usage() {
  cat <<'EOF'
Usage:
  doas ./scripts/install/run-phase-sequence.ksh [options]

Options:
  --phase-start N     First phase number to run, default 0
  --phase-end N       Last phase number to run, default 10
  --apply-only        Run apply scripts only
  --verify-only       Run verify scripts only
  --help              Show this help text

Environment:
  OPENBSD_MAILSTACK_NONINTERACTIVE=1   Disable prompting inside phase scripts
  SAVE_CONFIG=yes                      Allow phase scripts to write config files
EOF
}

validate_phase_number() {
  _value="$1"
  validate_numeric "${_value}" || return 1
  [ "${_value}" -ge 0 ] || return 1
  [ "${_value}" -le 99 ] || return 1
}

phase_script_path() {
  _phase_num="$1"
  _kind="$2"
  _phase_id="$(printf '%02d' "${_phase_num}")"
  print -- "${PROJECT_ROOT}/scripts/phases/phase-${_phase_id}-${_kind}.ksh"
}

run_phase_script() {
  _phase_num="$1"
  _kind="$2"
  _script="$(phase_script_path "${_phase_num}" "${_kind}")"
  [ -f "${_script}" ] || die "required phase script is missing: ${_script}"
  log_info "running phase $(printf '%02d' "${_phase_num}") ${_kind}: ${_script}"
  ksh "${_script}"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --phase-start)
        [ "$#" -ge 2 ] || die "--phase-start requires a numeric value"
        PHASE_START="$2"
        shift 2
        ;;
      --phase-end)
        [ "$#" -ge 2 ] || die "--phase-end requires a numeric value"
        PHASE_END="$2"
        shift 2
        ;;
      --apply-only)
        MODE="apply-only"
        shift
        ;;
      --verify-only)
        MODE="verify-only"
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  validate_phase_number "${PHASE_START}" || die "invalid --phase-start value: ${PHASE_START}"
  validate_phase_number "${PHASE_END}" || die "invalid --phase-end value: ${PHASE_END}"
  [ "${PHASE_START}" -le "${PHASE_END}" ] || die "phase start must be less than or equal to phase end"

  require_command ksh

  print_phase_header "PHASE-RUNNER" "phase sequence ${PHASE_START} through ${PHASE_END}"
  log_info "mode: ${MODE}"

  _phase="${PHASE_START}"
  while [ "${_phase}" -le "${PHASE_END}" ]; do
    if [ "${MODE}" != "verify-only" ]; then
      run_phase_script "${_phase}" "apply"
    fi
    if [ "${MODE}" != "apply-only" ]; then
      run_phase_script "${_phase}" "verify"
    fi
    _phase=$(( _phase + 1 ))
  done

  log_info "phase sequence completed successfully"
}

main "$@"
