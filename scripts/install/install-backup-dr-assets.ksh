#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${COMMON_LIB}"

MODE="${1:---dry-run}"
case "${MODE}" in
  --dry-run|--apply) ;;
  *) print -- "usage: $(basename "$0") --dry-run | --apply" >&2; exit 2 ;;
esac

LIBEXEC_DIR="/usr/local/libexec/openbsd-mailstack/backup-dr"
SBIN_DIR="/usr/local/sbin"

RUNTIME_SCRIPTS="backup-config.ksh backup-mariadb.ksh backup-mailstack.ksh backup-all.ksh protect-backup-set.ksh verify-backup-set.ksh restore-mailstack.ksh run-restore-drill.ksh replicate-backup-offhost.ksh"
INSTALL_HELPERS="install-backup-dr-assets.ksh install-dr-site-assets.ksh install-backup-schedule-assets.ksh provision-dr-site-host.ksh"

run() {
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ $*"
  else
    "$@"
  fi
}

[ "${MODE}" = "--dry-run" ] || [ "$(id -u)" -eq 0 ] || die "this action must run as root"
ensure_directory "${PROJECT_ROOT}/scripts/ops"
for _script in ${RUNTIME_SCRIPTS}; do
  [ -f "${PROJECT_ROOT}/scripts/ops/${_script}" ] || die "missing runtime script: ${_script}"
done
for _helper in ${INSTALL_HELPERS}; do
  [ -f "${PROJECT_ROOT}/scripts/install/${_helper}" ] || die "missing install helper: ${_helper}"
done

run install -d -m 0755 "${LIBEXEC_DIR}"
run install -d -m 0755 "${SBIN_DIR}"

for _script in ${RUNTIME_SCRIPTS}; do
  run install -m 0555 "${PROJECT_ROOT}/scripts/ops/${_script}" "${LIBEXEC_DIR}/${_script}"
  _name="openbsd-mailstack-${_script%.ksh}"
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ write wrapper ${SBIN_DIR}/${_name}"
  else
    cat > "${SBIN_DIR}/${_name}" <<EOF
#!/bin/sh
set -eu
exec ${LIBEXEC_DIR}/${_script} "\$@"
EOF
    chmod 0555 "${SBIN_DIR}/${_name}"
  fi
done

for _helper in ${INSTALL_HELPERS}; do
  _name="openbsd-mailstack-${_helper%.ksh}"
  run install -m 0555 "${PROJECT_ROOT}/scripts/install/${_helper}" "${SBIN_DIR}/${_name}"
done

print -- "backup and DR assets processed in mode ${MODE}"
