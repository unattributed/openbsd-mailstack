#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
[ -f "${COMMON_LIB}" ] || { print -- "ERROR missing shared library: ${COMMON_LIB}" >&2; exit 1; }
. "${COMMON_LIB}"

TARGET_ROOT="/"
if [ "${1:-}" = "--target-root" ]; then
  [ $# -eq 2 ] || die "usage: $0 [--target-root /path]"
  TARGET_ROOT="$2"
fi

GENERATED_ROOT="${PROJECT_ROOT}/services/generated/rootfs"
[ -d "${GENERATED_ROOT}" ] || "${PROJECT_ROOT}/scripts/install/render-core-runtime-configs.ksh"
[ -d "${GENERATED_ROOT}" ] || die "generated rootfs missing: ${GENERATED_ROOT}"
ensure_directory "${TARGET_ROOT}"
copy_tree_contents "${GENERATED_ROOT}" "${TARGET_ROOT}"
log_info "installed staged core runtime into ${TARGET_ROOT}"
