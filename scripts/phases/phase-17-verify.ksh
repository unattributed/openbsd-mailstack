#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
ADVANCED_LIB="${PROJECT_ROOT}/scripts/lib/advanced-gap-rollout.ksh"
PROFILE_LIB="${PROJECT_ROOT}/scripts/lib/advanced-phase-profiles.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing common library: ${COMMON_LIB}" >&2
  exit 1
}
[ -f "${ADVANCED_LIB}" ] || {
  print -- "ERROR missing advanced rollout library: ${ADVANCED_LIB}" >&2
  exit 1
}
[ -f "${PROFILE_LIB}" ] || {
  print -- "ERROR missing advanced profile library: ${PROFILE_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"
. "${ADVANCED_LIB}"
. "${PROFILE_LIB}"

FAIL=0
pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=$((FAIL + 1)); }

PLAN_DIR="$(advanced_profile_phase_dir 17)"

main() {
  print_phase_header "PHASE-17" "advanced optional integrations and gap closures verification"
  advanced_load_config
  validate_advanced_inputs

  ksh "${PROJECT_ROOT}/scripts/verify/verify-advanced-gap-assets.ksh" || FAIL=$((FAIL + 1))

  for _file in \
    "${PLAN_DIR}/suricata-plan.txt" \
    "${PLAN_DIR}/brevo-webhook-plan.txt" \
    "${PLAN_DIR}/sogo-plan.txt" \
    "${PLAN_DIR}/sbom-plan.txt" \
    "${PLAN_DIR}/phase-17-summary.txt" \
    "$(advanced_readiness_dir)/advanced-readiness.txt" \
    "${PROJECT_ROOT}/scripts/ops/advanced-readiness-report.ksh" \
    "${PROJECT_ROOT}/scripts/lib/advanced-phase-profiles.ksh"; do
    if [ -f "${_file}" ]; then
      pass "found ${_file}"
      if ! advanced_profile_check_no_placeholders "${_file}"; then
        fail "unresolved placeholder token found in ${_file}"
      fi
    else
      fail "missing ${_file}"
    fi
  done

  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL}"
  print

  [ "${FAIL}" -eq 0 ]
}

main "$@"
