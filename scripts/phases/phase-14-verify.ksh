#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
VERIFY_SCRIPT="${PROJECT_ROOT}/scripts/verify/verify-monitoring-assets.ksh"
FAIL=0
pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=$((FAIL + 1)); }

for _file in \
  "${PROJECT_ROOT}/services/generated/rootfs/etc/nginx/templates/openbsd-mailstack-ops-monitor.locations.tmpl" \
  "${PROJECT_ROOT}/services/generated/rootfs/etc/newsyslog.phase14-monitoring.conf" \
  "${PROJECT_ROOT}/services/generated/rootfs/etc/rspamd/local.d/logging.inc" \
  "${PROJECT_ROOT}/services/generated/rootfs/usr/local/share/examples/openbsd-mailstack-monitoring/root.cron.fragment" \
  "${PROJECT_ROOT}/services/generated/monitoring-summary.txt"
do
  [ -f "${_file}" ] && pass "found ${_file}" || fail "missing ${_file}"
done

[ -x "${VERIFY_SCRIPT}" ] && ksh "${VERIFY_SCRIPT}" || fail "monitoring verify helper failed"
[ "${FAIL}" -eq 0 ]
