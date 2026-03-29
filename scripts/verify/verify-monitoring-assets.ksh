#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
MONITOR_LIB="${PROJECT_ROOT}/scripts/lib/monitoring-diagnostics.ksh"
. "${COMMON_LIB}"
. "${MONITOR_LIB}"

monitoring_load_config

FAIL=0
pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=$((FAIL + 1)); }

for _file in \
  "${PROJECT_ROOT}/config/monitoring.conf.example" \
  "${PROJECT_ROOT}/scripts/lib/monitoring-diagnostics.ksh" \
  "${PROJECT_ROOT}/scripts/install/install-monitoring-assets.ksh" \
  "${PROJECT_ROOT}/scripts/ops/monitoring-log-summary.ksh" \
  "${PROJECT_ROOT}/scripts/ops/monitoring-collect.ksh" \
  "${PROJECT_ROOT}/scripts/ops/monitoring-render.ksh" \
  "${PROJECT_ROOT}/scripts/ops/mail-health-report.ksh" \
  "${PROJECT_ROOT}/scripts/ops/monitoring-run.ksh" \
  "${PROJECT_ROOT}/scripts/ops/rspamd-bayes-stats.ksh" \
  "${PROJECT_ROOT}/maint/alert-mail.ksh" \
  "${PROJECT_ROOT}/maint/cron-html-report.ksh" \
  "${PROJECT_ROOT}/maint/detect-services.ksh" \
  "${PROJECT_ROOT}/maint/verify-mailstack.ksh" \
  "${PROJECT_ROOT}/services/monitoring/cron/root.cron.fragment.template" \
  "${PROJECT_ROOT}/services/nginx/etc/nginx/templates/ops_monitor.locations.tmpl.template" \
  "${PROJECT_ROOT}/services/system/etc/newsyslog/phase14-managed-block.conf.template" \
  "${PROJECT_ROOT}/services/rspamd/etc/rspamd/local.d/logging.inc.template"
do
  [ -f "${_file}" ] && pass "found ${_file}" || fail "missing ${_file}"
done

if [ "${MONITORING_REQUIRE_RUNTIME_OUTPUT}" = "yes" ]; then
  for _runtime in \
    "${MONITORING_DATA_ROOT}/latest.kv" \
    "${MONITORING_DATA_ROOT}/latest.json" \
    "${MONITORING_SITE_ROOT}/index.html" \
    "${MONITORING_SITE_ROOT}/services.html" \
    "${MONITORING_SITE_ROOT}/logs.html" \
    "${MONITORING_SITE_ROOT}/changes.html"
  do
    [ -f "${_runtime}" ] && pass "runtime artifact present ${_runtime}" || fail "runtime artifact missing ${_runtime}"
  done
fi

[ "${FAIL}" -eq 0 ]
