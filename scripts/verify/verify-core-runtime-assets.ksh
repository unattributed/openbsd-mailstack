#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
[ -f "${COMMON_LIB}" ] || { print -- "ERROR missing shared library: ${COMMON_LIB}" >&2; exit 1; }
. "${COMMON_LIB}"

FAIL=0
pass() { print -- "[$(timestamp)] PASS  $*"; }
fail() { print -- "[$(timestamp)] FAIL  $*"; FAIL=$((FAIL + 1)); }

for _path in \
  services/mariadb/etc/my.cnf.template \
  services/postfix/etc/postfix/main.cf.template \
  services/postfix/etc/postfix/master.cf.template \
  services/dovecot/etc/dovecot/dovecot.conf.template \
  services/dovecot/etc/dovecot/local.conf.template \
  services/nginx/etc/nginx/sites-available/main.conf.template \
  services/nginx/etc/nginx/sites-available/main-ssl.conf.template \
  services/postfixadmin/var/www/postfixadmin/config.local.php.template \
  services/roundcube/var/www/roundcubemail/config/config.inc.php.template \
  services/rspamd/etc/rspamd/local.d/worker-controller.inc.template \
  services/rspamd/etc/rspamd/local.d/worker-proxy.inc.template \
  services/redis/etc/redis.conf.template \
  services/clamd/etc/clamd.conf.template \
  services/freshclam/etc/freshclam.conf.template \
  scripts/install/render-core-runtime-configs.ksh \
  scripts/install/install-core-runtime-configs.ksh; do
  [ -f "${PROJECT_ROOT}/${_path}" ] && pass "present: ${_path}" || fail "missing: ${_path}"
done

CORE_RENDER_ROOT="$(core_runtime_render_root)"
[ -d "${CORE_RENDER_ROOT}" ] && pass "live rendered rootfs exists: ${CORE_RENDER_ROOT}" || fail "live rendered rootfs not present yet at ${CORE_RENDER_ROOT}, run render-core-runtime-configs.ksh"

if [ -d "${CORE_RENDER_ROOT}" ]; then
  _expected_mode="$(normalize_mode_octal "$(runtime_secret_file_mode)")"
  while IFS= read -r _rel || [ -n "${_rel}" ]; do
    [ -n "${_rel}" ] || continue
    _path="${CORE_RENDER_ROOT%/}/${_rel}"
    if [ -f "${_path}" ]; then
      _actual_mode="$(normalize_mode_octal "$(file_mode_octal "${_path}")")"
      if [ -n "${_actual_mode}" ] && [ "${_actual_mode}" = "${_expected_mode}" ]; then
        pass "live runtime secret mode ok (${_actual_mode}): ${_path}"
      else
        fail "live runtime secret mode mismatch, expected ${_expected_mode}, got ${_actual_mode:-unknown}: ${_path}"
      fi
    else
      fail "live runtime secret file missing: ${_path}"
    fi
  done <<EOF
$(core_runtime_secret_relative_paths)
EOF
fi
[ ${FAIL} -eq 0 ]
