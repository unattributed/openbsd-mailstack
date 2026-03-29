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

[ -d "${PROJECT_ROOT}/services/generated/rootfs" ] && pass "rendered rootfs exists" || fail "rendered rootfs not present yet, run render-core-runtime-configs.ksh"
[ ${FAIL} -eq 0 ]
