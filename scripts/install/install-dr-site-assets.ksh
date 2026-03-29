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

ASSET_ROOT="${PROJECT_ROOT}/maint/dr-site"
HTDOCS_ROOT="${ASSET_ROOT}/htdocs"
TEMPLATE_SRC="${ASSET_ROOT}/nginx/dr-site.locations.template"

load_project_config
prompt_value "DR_SITE_ENABLED" "Enable the DR site, yes or no" "${DR_SITE_ENABLED:-yes}"
prompt_value "DR_SITE_DOC_TITLE" "Enter the DR site title" "${DR_SITE_DOC_TITLE:-openbsd-mailstack disaster recovery}"
prompt_value "DR_SITE_SERVER_NAME" "Enter the DR site server name" "${DR_SITE_SERVER_NAME:-dr.example.com}"
prompt_value "DR_SITE_OPERATOR_EMAIL" "Enter the DR site operator email" "${DR_SITE_OPERATOR_EMAIL:-ops@example.com}"
prompt_value "DR_SITE_RECOVERY_CHANNEL" "Enter the DR site recovery channel" "${DR_SITE_RECOVERY_CHANNEL:-WireGuard or dedicated management network}"
prompt_value "DR_SITE_RESTORE_HOSTNAME" "Enter the DR restore hostname" "${DR_SITE_RESTORE_HOSTNAME:-mail-dr.example.com}"
prompt_value "DR_SITE_URL_PATH" "Enter the DR site URL path" "${DR_SITE_URL_PATH:-/dr/}"
prompt_value "DR_SITE_PUBLISH_ROOT" "Enter the publish root" "${DR_SITE_PUBLISH_ROOT:-/var/www/htdocs/dr}"
prompt_value "DR_SITE_CHROOT_ALIAS" "Enter the nginx chroot alias" "${DR_SITE_CHROOT_ALIAS:-/htdocs/dr}"
prompt_value "DR_SITE_TEMPLATE_ROOT" "Enter the nginx template root" "${DR_SITE_TEMPLATE_ROOT:-/etc/nginx/templates}"
prompt_value "DR_SITE_LOCATION_TEMPLATE" "Enter the nginx template filename" "${DR_SITE_LOCATION_TEMPLATE:-openbsd-mailstack-dr-site.locations.tmpl}"
prompt_value "DR_SITE_ALLOW_TEMPLATE" "Enter the nginx allow include template" "${DR_SITE_ALLOW_TEMPLATE:-/etc/nginx/templates/control-plane-allow.tmpl}"
prompt_value "DR_SITE_NGINX_SERVER_CONF" "Enter the nginx server conf to optionally patch" "${DR_SITE_NGINX_SERVER_CONF:-/etc/nginx/sites-available/main-ssl.conf}"
prompt_value "DR_SITE_PATCH_SERVER_CONF" "Patch the nginx server conf automatically, yes or no" "${DR_SITE_PATCH_SERVER_CONF:-no}"
prompt_value "DR_SITE_BACKUP_ROOT" "Enter the DR site backup root" "${DR_SITE_BACKUP_ROOT:-/var/backups/openbsd-mailstack/dr-site}"

validate_yes_no "${DR_SITE_ENABLED}" || die "DR_SITE_ENABLED must be yes or no"
validate_yes_no "${DR_SITE_PATCH_SERVER_CONF}" || die "DR_SITE_PATCH_SERVER_CONF must be yes or no"
validate_hostname "${DR_SITE_SERVER_NAME}" || die "invalid DR_SITE_SERVER_NAME: ${DR_SITE_SERVER_NAME}"
validate_email "${DR_SITE_OPERATOR_EMAIL}" || die "invalid DR_SITE_OPERATOR_EMAIL: ${DR_SITE_OPERATOR_EMAIL}"
validate_absolute_path "${DR_SITE_PUBLISH_ROOT}" || die "invalid DR_SITE_PUBLISH_ROOT: ${DR_SITE_PUBLISH_ROOT}"
validate_absolute_path "${DR_SITE_TEMPLATE_ROOT}" || die "invalid DR_SITE_TEMPLATE_ROOT: ${DR_SITE_TEMPLATE_ROOT}"
validate_absolute_path "${DR_SITE_ALLOW_TEMPLATE}" || die "invalid DR_SITE_ALLOW_TEMPLATE: ${DR_SITE_ALLOW_TEMPLATE}"
validate_absolute_path "${DR_SITE_BACKUP_ROOT}" || die "invalid DR_SITE_BACKUP_ROOT: ${DR_SITE_BACKUP_ROOT}"

DR_SITE_URL_PATH_BASE="${DR_SITE_URL_PATH%/}"
[ -n "${DR_SITE_URL_PATH_BASE}" ] || DR_SITE_URL_PATH_BASE="/dr"

[ "${DR_SITE_ENABLED}" = "yes" ] || { print -- "DR site disabled by configuration"; exit 0; }
[ -d "${HTDOCS_ROOT}" ] || die "missing DR site asset tree: ${HTDOCS_ROOT}"
[ -f "${TEMPLATE_SRC}" ] || die "missing DR site nginx template: ${TEMPLATE_SRC}"

run() {
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ $*"
  else
    "$@"
  fi
}

backup_path() {
  _path="$1"
  [ -e "${_path}" ] || return 0
  _stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  _target="${DR_SITE_BACKUP_ROOT}/${_stamp}${_path}"
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ backup ${_path} to ${_target}"
  else
    ensure_directory "$(dirname -- "${_target}")"
    cp -Rp "${_path}" "${_target}"
  fi
}

patch_server_conf() {
  _conf="$1"
  _include_line="    include ${DR_SITE_TEMPLATE_ROOT}/${DR_SITE_LOCATION_TEMPLATE};"
  [ -f "${_conf}" ] || die "nginx server conf not found: ${_conf}"
  if grep -Fq "${_include_line}" "${_conf}"; then
    print -- "include already present in ${_conf}"
    return 0
  fi
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ would insert '${_include_line}' into ${_conf}"
    return 0
  fi
  _tmp="$(mktemp)"
  awk -v add="${_include_line}" '
    { lines[NR]=$0 }
    END {
      inserted=0
      for (i=1; i<=NR; i++) {
        if (!inserted && lines[i] ~ /^}/) {
          print add
          inserted=1
        }
        print lines[i]
      }
      if (!inserted) print add
    }
  ' "${_conf}" > "${_tmp}"
  install -m 0644 "${_tmp}" "${_conf}"
  rm -f "${_tmp}"
}

[ "${MODE}" = "--dry-run" ] || [ "$(id -u)" -eq 0 ] || die "this action must run as root"
run install -d -m 0755 "${DR_SITE_PUBLISH_ROOT}"
run install -d -m 0755 "${DR_SITE_TEMPLATE_ROOT}"
run install -d -m 0700 "${DR_SITE_BACKUP_ROOT}"
backup_path "${DR_SITE_PUBLISH_ROOT}"
backup_path "${DR_SITE_TEMPLATE_ROOT}/${DR_SITE_LOCATION_TEMPLATE}"
[ "${DR_SITE_PATCH_SERVER_CONF}" = "yes" ] && backup_path "${DR_SITE_NGINX_SERVER_CONF}"

for _src in $(find "${HTDOCS_ROOT}" -type f | sort); do
  _rel="${_src#${HTDOCS_ROOT}/}"
  _dst="${DR_SITE_PUBLISH_ROOT}/${_rel}"
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "+ render ${_src} -> ${_dst}"
  else
    render_template_file "${_src}" "${_dst}"       "DR_SITE_DOC_TITLE=${DR_SITE_DOC_TITLE}"       "DR_SITE_SERVER_NAME=${DR_SITE_SERVER_NAME}"       "DR_SITE_OPERATOR_EMAIL=${DR_SITE_OPERATOR_EMAIL}"       "DR_SITE_RECOVERY_CHANNEL=${DR_SITE_RECOVERY_CHANNEL}"       "DR_SITE_RESTORE_HOSTNAME=${DR_SITE_RESTORE_HOSTNAME}"       "DR_SITE_URL_PATH=${DR_SITE_URL_PATH}"       "DR_SITE_URL_PATH_BASE=${DR_SITE_URL_PATH_BASE}"
  fi
done

if [ "${MODE}" = "--dry-run" ]; then
  print -- "+ render ${TEMPLATE_SRC} -> ${DR_SITE_TEMPLATE_ROOT}/${DR_SITE_LOCATION_TEMPLATE}"
else
  render_template_file "${TEMPLATE_SRC}" "${DR_SITE_TEMPLATE_ROOT}/${DR_SITE_LOCATION_TEMPLATE}"     "DR_SITE_URL_PATH=${DR_SITE_URL_PATH}"     "DR_SITE_URL_PATH_BASE=${DR_SITE_URL_PATH_BASE}"     "DR_SITE_CHROOT_ALIAS=${DR_SITE_CHROOT_ALIAS}"     "DR_SITE_ALLOW_TEMPLATE=${DR_SITE_ALLOW_TEMPLATE}"
fi

[ "${DR_SITE_PATCH_SERVER_CONF}" = "yes" ] && patch_server_conf "${DR_SITE_NGINX_SERVER_CONF}"

if [ "${MODE}" = "--apply" ] && command_exists nginx; then
  nginx -t || die "nginx validation failed after DR site provisioning"
fi

print -- "DR site assets processed in mode ${MODE}"
