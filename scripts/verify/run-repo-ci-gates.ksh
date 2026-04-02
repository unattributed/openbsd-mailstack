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

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/openbsd-mailstack-ci.XXXXXX")"
INPUT_ROOT="${TMP_ROOT}/inputs"
CI_HOME="${TMP_ROOT}/home"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT INT TERM HUP

run() {
  log_info "running: $*"
  "$@"
}

copy_example_configs() {
  ensure_directory "${INPUT_ROOT}"
  for _src in "${PROJECT_ROOT}"/config/*.example; do
    [ -f "${_src}" ] || continue
    _base="$(basename -- "${_src}" .example)"
    cp -f "${_src}" "${INPUT_ROOT}/${_base}" || die "failed copying example config ${_src}"
  done
}

write_ci_overrides() {
  cat >> "${INPUT_ROOT}/secrets.conf" <<'EOF2'
VULTR_API_KEY="ci-vultr-api-key"
BREVO_API_KEY="ci-brevo-api-key"
BREVO_SMTP_KEY="ci-brevo-smtp-key"
VIRUSTOTAL_API_KEY="ci-virustotal-api-key"
BREVO_SMTP_LOGIN="ci-brevo-login"
BREVO_SMTP_PASSWORD="ci-brevo-password"
POSTFIXADMIN_SETUP_PASSWORD_HASH="ci-postfixadmin-setup-hash"
RSPAMD_CONTROLLER_PASSWORD_HASH="ci-rspamd-password-hash"
EOF2
}

prepare_ci_environment() {
  copy_example_configs
  write_ci_overrides
  ensure_directory "${CI_HOME}"

  export HOME="${CI_HOME}"
  export OPENBSD_MAILSTACK_NONINTERACTIVE=1
  export OPENBSD_MAILSTACK_INPUT_ROOT="${INPUT_ROOT}"
  export OPENBSD_MAILSTACK_EXTRA_INPUT_FILES=""
  export OPENBSD_MAILSTACK_CORE_RENDER_ROOT="${TMP_ROOT}/runtime/rootfs"
  export OPENBSD_MAILSTACK_NETWORK_RENDER_ROOT="${TMP_ROOT}/network/rootfs"
  export OPENBSD_MAILSTACK_IDENTITY_RENDER_ROOT="${TMP_ROOT}/identity"
  export OPENBSD_MAILSTACK_ADVANCED_RENDER_ROOT="${TMP_ROOT}/advanced/rootfs"
  export OPENBSD_MAILSTACK_ADVANCED_SBOM_ROOT="${TMP_ROOT}/advanced/sbom"
  export OPENBSD_MAILSTACK_BACKUP_DR_WORK_ROOT="${TMP_ROOT}/backup-dr"
  export OPENBSD_MAILSTACK_OPERATIONS_WORK_ROOT="${TMP_ROOT}/operations"
  export OPENBSD_MAILSTACK_AUTOINSTALL_BUILD_ROOT="${TMP_ROOT}/autoinstall-build"
}

main() {
  prepare_ci_environment

  run "${PROJECT_ROOT}/scripts/verify/verify-documentation-integrity.ksh"
  run "${PROJECT_ROOT}/scripts/verify/verify-repo-semantic-integrity.ksh"
  run "${PROJECT_ROOT}/scripts/verify/verify-public-repo-readiness.ksh"
  run "${PROJECT_ROOT}/scripts/verify/verify-lab-assets.ksh"
  run "${PROJECT_ROOT}/maint/openbsd-autonomous-installer/guided-profile-builder.ksh" --noninteractive --output "${TMP_ROOT}/installer-profile.local.env"
  run "${PROJECT_ROOT}/maint/openbsd-autonomous-installer/render-installer-pack.ksh" --profile "${TMP_ROOT}/installer-profile.local.env"
  run "${PROJECT_ROOT}/scripts/verify/verify-autonomous-installer-assets.ksh"

  run "${PROJECT_ROOT}/scripts/install/render-core-runtime-configs.ksh"
  run "${PROJECT_ROOT}/scripts/verify/verify-core-runtime-assets.ksh"
  run "${PROJECT_ROOT}/scripts/verify/verify-rendered-config-integrity.ksh"

  run "${PROJECT_ROOT}/scripts/phases/phase-02-verify.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-03-verify.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-04-verify.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-05-verify.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-06-verify.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-07-verify.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-08-verify.ksh"

  run "${PROJECT_ROOT}/scripts/install/render-network-exposure-configs.ksh"
  run "${PROJECT_ROOT}/scripts/verify/verify-network-exposure-assets.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-09-apply.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-09-verify.ksh"

  run "${PROJECT_ROOT}/scripts/install/render-advanced-gap-configs.ksh"
  run "${PROJECT_ROOT}/scripts/verify/verify-advanced-gap-assets.ksh"

  run "${PROJECT_ROOT}/scripts/phases/phase-10-apply.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-10-verify.ksh"
  run "${PROJECT_ROOT}/scripts/ops/operations-readiness-report.ksh" --write

  run "${PROJECT_ROOT}/scripts/phases/phase-11-apply.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-11-verify.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-12-apply.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-12-verify.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-13-apply.ksh"
  run "${PROJECT_ROOT}/scripts/phases/phase-13-verify.ksh"
  run "${PROJECT_ROOT}/scripts/ops/backup-dr-readiness-report.ksh" --write
  run "${PROJECT_ROOT}/scripts/verify/verify-backup-dr-assets.ksh"

  run "${PROJECT_ROOT}/maint/validate-public-hardening-surface.ksh"

  log_info "repo-only CI gates completed successfully"
}

main "$@"
