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

MODE="print"
if [ "${1:-}" = "--write" ]; then
  MODE="write"
fi

advanced_load_config
validate_advanced_inputs

GEN_ROOT="${OPENBSD_MAILSTACK_ADVANCED_RENDER_ROOT:-${PROJECT_ROOT}/.work/advanced/rootfs}"
SBOM_ROOT="${OPENBSD_MAILSTACK_ADVANCED_SBOM_ROOT:-${PROJECT_ROOT}/.work/advanced/sbom}"
REPORT_PATH="$(advanced_readiness_dir)/advanced-readiness.txt"

REPORT_CONTENT="Advanced optional integration readiness report
suricata enabled: ${ENABLE_SURICATA}
brevo webhook enabled: ${ENABLE_BREVO_WEBHOOK}
sogo enabled: ${ENABLE_SOGO}
sbom enabled: ${ENABLE_SBOM}
sbom scanner mode: ${SBOM_SCANNER_MODE}
render root: ${GEN_ROOT}
sbom root: ${SBOM_ROOT}
phase 17 plan directory: $(advanced_profile_phase_dir 17)
render entrypoint: ${PROJECT_ROOT}/scripts/install/render-advanced-gap-configs.ksh
verify entrypoint: ${PROJECT_ROOT}/scripts/verify/verify-advanced-gap-assets.ksh
phase apply entrypoint: ${PROJECT_ROOT}/scripts/phases/phase-17-apply.ksh
phase verify entrypoint: ${PROJECT_ROOT}/scripts/phases/phase-17-verify.ksh"

if [ "${MODE}" = "write" ]; then
  advanced_profile_write_text "${REPORT_PATH}" "${REPORT_CONTENT}"
  print -- "${REPORT_PATH}"
else
  print -- "${REPORT_CONTENT}"
fi
