#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"

usage() {
  cat <<'EOF' >&2
usage: runtime-secret-layout.ksh --plan|--install-dirs|--render-stubs <output_dir>|--verify
EOF
  exit 2
}

need_root() {
  [ "$(id -u)" -eq 0 ] || die "must run as root via doas"
}

load_settings() {
  load_project_config
  : "${RUNTIME_SECRET_DIR:=/root/.config/openbsd-mailstack/runtime}"
  : "${RUNTIME_PROVIDER_DIR:=/root/.config/openbsd-mailstack/providers}"
  : "${RUNTIME_DR_DIR:=/root/.config/openbsd-mailstack/dr}"
  : "${POSTFIXADMIN_DB_ENV_PATH:=${RUNTIME_SECRET_DIR}/postfixadmin-db.env}"
  : "${SOGO_DB_ENV_PATH:=${RUNTIME_SECRET_DIR}/sogo-db.env}"
  : "${POSTFIXADMIN_SECRETS_PHP_PATH:=/etc/postfixadmin/secrets.php}"
  : "${ROUNDCUBE_SECRETS_INC_PHP_PATH:=/etc/roundcube/secrets.inc.php}"
  : "${VIRUSTOTAL_ENV_PATH:=${RUNTIME_PROVIDER_DIR}/virustotal.env}"
  : "${DR_RUNTIME_ENV_PATH:=${RUNTIME_DR_DIR}/obsd1.env}"
  : "${DR_GITHUB_PAT_PATH:=${RUNTIME_DR_DIR}/github.pat}"
  : "${RUNTIME_SECRET_OWNER:=root}"
  : "${RUNTIME_SECRET_GROUP:=wheel}"
  : "${RUNTIME_SECRET_FILE_MODE:=0600}"
  : "${RUNTIME_SECRET_DIR_MODE:=0700}"
}

print_layout() {
  load_settings
  cat <<EOF
Directories:
- ${RUNTIME_SECRET_DIR}
- ${RUNTIME_PROVIDER_DIR}
- ${RUNTIME_DR_DIR}
- /etc/postfixadmin
- /etc/roundcube

Files:
- ${POSTFIXADMIN_DB_ENV_PATH}
- ${SOGO_DB_ENV_PATH}
- ${POSTFIXADMIN_SECRETS_PHP_PATH}
- ${ROUNDCUBE_SECRETS_INC_PHP_PATH}
- ${VIRUSTOTAL_ENV_PATH}
- ${DR_RUNTIME_ENV_PATH}
- ${DR_GITHUB_PAT_PATH}

Ownership and mode:
- owner=${RUNTIME_SECRET_OWNER}
- group=${RUNTIME_SECRET_GROUP}
- file mode=${RUNTIME_SECRET_FILE_MODE}
- dir mode=${RUNTIME_SECRET_DIR_MODE}
EOF
}

install_dirs() {
  need_root
  load_settings
  install -d -m "${RUNTIME_SECRET_DIR_MODE}" "${RUNTIME_SECRET_DIR}" "${RUNTIME_PROVIDER_DIR}" "${RUNTIME_DR_DIR}" /etc/postfixadmin /etc/roundcube
  print -- "ok: created runtime secret directories"
}

render_stubs() {
  _out="${1:?output directory required}"
  load_settings
  install -d -m 0755 "${_out}/runtime" "${_out}/providers" "${_out}/dr" "${_out}/etc/postfixadmin" "${_out}/etc/roundcube"
  install -m 0644 "${PROJECT_ROOT}/services/secrets/etc/examples/postfixadmin-db.env.template" "${_out}/runtime/postfixadmin-db.env"
  install -m 0644 "${PROJECT_ROOT}/services/secrets/etc/examples/sogo-db.env.template" "${_out}/runtime/sogo-db.env"
  install -m 0644 "${PROJECT_ROOT}/services/secrets/etc/postfixadmin/secrets.php.template" "${_out}/etc/postfixadmin/secrets.php"
  install -m 0644 "${PROJECT_ROOT}/services/secrets/etc/roundcube/secrets.inc.php.template" "${_out}/etc/roundcube/secrets.inc.php"
  : > "${_out}/providers/virustotal.env"
  : > "${_out}/dr/obsd1.env"
  : > "${_out}/dr/github.pat"
  print -- "ok: rendered runtime secret stubs under ${_out}"
}

check_one() {
  _path="$1"
  if [ -e "${_path}" ]; then
    print -- "PASS ${_path} exists"
  else
    print -- "WARN ${_path} missing"
  fi
}

verify_mode() {
  load_settings
  for _path in     "${RUNTIME_SECRET_DIR}"     "${RUNTIME_PROVIDER_DIR}"     "${RUNTIME_DR_DIR}"     "/etc/postfixadmin"     "/etc/roundcube"     "${POSTFIXADMIN_DB_ENV_PATH}"     "${SOGO_DB_ENV_PATH}"     "${POSTFIXADMIN_SECRETS_PHP_PATH}"     "${ROUNDCUBE_SECRETS_INC_PHP_PATH}"     "${VIRUSTOTAL_ENV_PATH}"     "${DR_RUNTIME_ENV_PATH}"     "${DR_GITHUB_PAT_PATH}"; do
    check_one "${_path}"
  done
}

case "${1:-}" in
  --plan) print_layout ;;
  --install-dirs) install_dirs ;;
  --render-stubs) shift; [ $# -gt 0 ] || usage; render_stubs "$1" ;;
  --verify) verify_mode ;;
  *) usage ;;
esac
