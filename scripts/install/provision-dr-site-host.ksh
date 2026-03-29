#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${COMMON_LIB}"

INSTALL_DR_SITE_ASSETS="${PROJECT_ROOT}/scripts/install/install-dr-site-assets.ksh"
MODE="${1:---dry-run}"
case "${MODE}" in
  --dry-run|--apply) ;;
  *) print -- "usage: $(basename "$0") --dry-run | --apply" >&2; exit 2 ;;
esac

load_project_config
prompt_value "DR_HOST_ENABLED" "Enable DR host bootstrap, yes or no" "${DR_HOST_ENABLED:-yes}"
prompt_value "DR_HOST_BASE_ROOT" "Enter the DR host base root" "${DR_HOST_BASE_ROOT:-/srv/openbsd-mailstack-dr}"
prompt_value "DR_HOST_RESTORE_ROOT" "Enter the DR restore root" "${DR_HOST_RESTORE_ROOT:-/var/restore/openbsd-mailstack}"
prompt_value "DR_HOST_BACKUP_ROOT" "Enter the DR backup root" "${DR_HOST_BACKUP_ROOT:-/var/backups/openbsd-mailstack}"
prompt_value "DR_HOST_RUNTIME_ROOT" "Enter the DR runtime root" "${DR_HOST_RUNTIME_ROOT:-/var/lib/openbsd-mailstack-dr}"
prompt_value "DR_HOST_LOG_ROOT" "Enter the DR log root" "${DR_HOST_LOG_ROOT:-/var/log/openbsd-mailstack-dr}"
prompt_value "DR_HOST_INSTALL_PORTAL" "Install the DR portal assets, yes or no" "${DR_HOST_INSTALL_PORTAL:-yes}"
prompt_value "DR_HOST_PATCH_NGINX" "Patch nginx while bootstrapping the DR host, yes or no" "${DR_HOST_PATCH_NGINX:-no}"
prompt_value "DR_HOST_BOOTSTRAP_REPORT" "Write a bootstrap report, yes or no" "${DR_HOST_BOOTSTRAP_REPORT:-yes}"

validate_yes_no "${DR_HOST_ENABLED}" || die "DR_HOST_ENABLED must be yes or no"
validate_yes_no "${DR_HOST_INSTALL_PORTAL}" || die "DR_HOST_INSTALL_PORTAL must be yes or no"
validate_yes_no "${DR_HOST_PATCH_NGINX}" || die "DR_HOST_PATCH_NGINX must be yes or no"
validate_yes_no "${DR_HOST_BOOTSTRAP_REPORT}" || die "DR_HOST_BOOTSTRAP_REPORT must be yes or no"
validate_absolute_path "${DR_HOST_BASE_ROOT}" || die "invalid DR_HOST_BASE_ROOT: ${DR_HOST_BASE_ROOT}"
validate_absolute_path "${DR_HOST_RESTORE_ROOT}" || die "invalid DR_HOST_RESTORE_ROOT: ${DR_HOST_RESTORE_ROOT}"
validate_absolute_path "${DR_HOST_BACKUP_ROOT}" || die "invalid DR_HOST_BACKUP_ROOT: ${DR_HOST_BACKUP_ROOT}"
validate_absolute_path "${DR_HOST_RUNTIME_ROOT}" || die "invalid DR_HOST_RUNTIME_ROOT: ${DR_HOST_RUNTIME_ROOT}"
validate_absolute_path "${DR_HOST_LOG_ROOT}" || die "invalid DR_HOST_LOG_ROOT: ${DR_HOST_LOG_ROOT}"

[ "${DR_HOST_ENABLED}" = "yes" ] || { print -- "DR host bootstrap disabled by configuration"; exit 0; }

report_path="${DR_HOST_RUNTIME_ROOT}/dr-host-bootstrap-report.txt"

run() {
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ $*"
  else
    "$@"
  fi
}

[ "${MODE}" = "--dry-run" ] || [ "$(id -u)" -eq 0 ] || die "this action must run as root"

for _dir in   "${DR_HOST_BASE_ROOT}"   "${DR_HOST_BASE_ROOT}/staging"   "${DR_HOST_BASE_ROOT}/releases"   "${DR_HOST_RESTORE_ROOT}"   "${DR_HOST_BACKUP_ROOT}"   "${DR_HOST_BACKUP_ROOT}/mailstack"   "${DR_HOST_BACKUP_ROOT}/mariadb"   "${DR_HOST_BACKUP_ROOT}/config"   "${DR_HOST_RUNTIME_ROOT}"   "${DR_HOST_LOG_ROOT}"; do
  run install -d -m 0755 "${_dir}"
done

if [ "${DR_HOST_INSTALL_PORTAL}" = "yes" ]; then
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ DR_HOST_PATCH_NGINX=${DR_HOST_PATCH_NGINX} ksh ${INSTALL_DR_SITE_ASSETS} --dry-run"
  else
    DR_SITE_PATCH_SERVER_CONF="${DR_HOST_PATCH_NGINX}" ksh "${INSTALL_DR_SITE_ASSETS}" --apply
  fi
fi

if [ "${DR_HOST_BOOTSTRAP_REPORT}" = "yes" ]; then
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ would write ${report_path}"
  else
    cat > "${report_path}" <<EOF
openbsd-mailstack DR host bootstrap report
base_root: ${DR_HOST_BASE_ROOT}
restore_root: ${DR_HOST_RESTORE_ROOT}
backup_root: ${DR_HOST_BACKUP_ROOT}
runtime_root: ${DR_HOST_RUNTIME_ROOT}
log_root: ${DR_HOST_LOG_ROOT}
portal_installed: ${DR_HOST_INSTALL_PORTAL}
nginx_patched: ${DR_HOST_PATCH_NGINX}
EOF
    chmod 0644 "${report_path}"
  fi
fi

print -- "DR host bootstrap processed in mode ${MODE}"
