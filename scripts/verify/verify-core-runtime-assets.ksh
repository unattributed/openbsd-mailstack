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
warn() { print -- "[$(timestamp)] WARN  $*"; }
fail() { print -- "[$(timestamp)] FAIL  $*"; FAIL=$((FAIL + 1)); }

for _path in   services/mariadb/etc/my.cnf.template   services/postfix/etc/postfix/main.cf.template   services/postfix/etc/postfix/master.cf.template   services/dovecot/etc/dovecot/dovecot.conf.template   services/dovecot/etc/dovecot/local.conf.template   services/nginx/etc/nginx/sites-available/main.conf.template   services/nginx/etc/nginx/sites-available/main-ssl.conf.template   services/postfixadmin/var/www/postfixadmin/config.local.php.template   services/roundcube/var/www/roundcubemail/config/config.inc.php.template   services/rspamd/etc/rspamd/local.d/worker-controller.inc.template   services/rspamd/etc/rspamd/local.d/worker-proxy.inc.template   services/redis/etc/redis.conf.template   services/clamd/etc/clamd.conf.template   services/freshclam/etc/freshclam.conf.template   scripts/install/render-core-runtime-configs.ksh   scripts/install/install-core-runtime-configs.ksh; do
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

  _postmap="$(find_postmap_command)"
  if [ -n "${_postmap}" ]; then
    while IFS= read -r _rel || [ -n "${_rel}" ]; do
      [ -n "${_rel}" ] || continue
      _source_path="${CORE_RENDER_ROOT%/}/${_rel}"
      _db_path="${_source_path}.db"
      if [ -f "${_source_path}" ]; then
        [ -f "${_db_path}" ] && pass "live postfix hash map present: ${_db_path}" || fail "live postfix hash map missing: ${_db_path}"
      else
        fail "live postfix hash source file missing: ${_source_path}"
      fi
    done <<EOF
$(postfix_hash_source_relative_paths)
EOF

    _sasl_db="${CORE_RENDER_ROOT%/}/etc/postfix/sasl_passwd.db"
    if [ -f "${_sasl_db}" ]; then
      _actual_mode="$(normalize_mode_octal "$(file_mode_octal "${_sasl_db}")")"
      if [ -n "${_actual_mode}" ] && [ "${_actual_mode}" = "${_expected_mode}" ]; then
        pass "live postfix sasl hash map mode ok (${_actual_mode}): ${_sasl_db}"
      else
        fail "live postfix sasl hash map mode mismatch, expected ${_expected_mode}, got ${_actual_mode:-unknown}: ${_sasl_db}"
      fi
    else
      fail "live postfix sasl hash map missing: ${_sasl_db}"
    fi
  else
    warn "postmap not available, skipping live postfix hash map verification under ${CORE_RENDER_ROOT}"
  fi
fi
[ ${FAIL} -eq 0 ]
