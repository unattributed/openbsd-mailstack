#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
[ -f "${COMMON_LIB}" ] || { print -- "ERROR missing shared library: ${COMMON_LIB}" >&2; exit 1; }
. "${COMMON_LIB}"

TARGET_ROOT="/"
GENERATED_ROOT="$(core_runtime_render_root)"
EXAMPLE_ROOT="$(core_runtime_example_root)"

usage() {
  cat <<EOF
usage: $0 [--target-root /path] [--render-root /path]
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --target-root)
        [ $# -ge 2 ] || die "missing value for --target-root"
        TARGET_ROOT="$2"
        shift 2
        ;;
      --render-root)
        [ $# -ge 2 ] || die "missing value for --render-root"
        GENERATED_ROOT="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        die "unknown argument: $1"
        ;;
    esac
  done
}

validate_render_root() {
  case "${GENERATED_ROOT}" in
    "${EXAMPLE_ROOT}"|${EXAMPLE_ROOT}/*)
      die "refusing to install from tracked sanitized example tree: ${EXAMPLE_ROOT}"
      ;;
  esac
}

main() {
  parse_args "$@"
  validate_render_root
  [ -d "${GENERATED_ROOT}" ] || "${PROJECT_ROOT}/scripts/install/render-core-runtime-configs.ksh" --output-root "${GENERATED_ROOT}"
  [ -d "${GENERATED_ROOT}" ] || die "generated rootfs missing: ${GENERATED_ROOT}"
  ensure_directory "${TARGET_ROOT}"
  copy_tree_contents "${GENERATED_ROOT}" "${TARGET_ROOT}"
  enforce_core_runtime_secret_permissions_in_tree "${TARGET_ROOT}"
  log_info "installed staged core runtime from ${GENERATED_ROOT} into ${TARGET_ROOT} with runtime secret permissions enforced"
}

main "$@"
