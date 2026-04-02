#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${PROJECT_ROOT}/scripts/lib/advanced-gap-rollout.ksh"

advanced_load_config
validate_advanced_inputs

FAIL=0
pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=$((FAIL + 1)); }
check() { [ -f "$1" ] && pass "found $1" || fail "missing $1"; }
check_contains() {
  _file="$1"
  _needle="$2"
  if grep -Fq -- "${_needle}" "${_file}" 2>/dev/null; then
    pass "found ${_needle} in ${_file}"
  else
    fail "missing ${_needle} in ${_file}"
  fi
}

for _file in \
  "${PROJECT_ROOT}/config/suricata.conf.example" \
  "${PROJECT_ROOT}/config/brevo-webhook.conf.example" \
  "${PROJECT_ROOT}/config/sogo.conf.example" \
  "${PROJECT_ROOT}/config/sbom.conf.example" \
  "${PROJECT_ROOT}/scripts/lib/advanced-gap-rollout.ksh" \
  "${PROJECT_ROOT}/scripts/lib/advanced-phase-profiles.ksh" \
  "${PROJECT_ROOT}/scripts/install/render-advanced-gap-configs.ksh" \
  "${PROJECT_ROOT}/scripts/install/install-advanced-gap-assets.ksh" \
  "${PROJECT_ROOT}/scripts/ops/advanced-readiness-report.ksh" \
  "${PROJECT_ROOT}/scripts/ops/suricata-dump.ksh" \
  "${PROJECT_ROOT}/scripts/ops/suricata-eve2pf.ksh" \
  "${PROJECT_ROOT}/scripts/ops/sbom-daily-scan.ksh" \
  "${PROJECT_ROOT}/scripts/phases/phase-17-apply.ksh" \
  "${PROJECT_ROOT}/scripts/phases/phase-17-verify.ksh" \
  "${PROJECT_ROOT}/services/suricata/etc/suricata/suricata.yaml.template" \
  "${PROJECT_ROOT}/services/brevo/usr/local/sbin/brevo_webhook.py.template" \
  "${PROJECT_ROOT}/services/sogo/etc/sogo/sogo.conf.template" \
  "${PROJECT_ROOT}/services/sbom/components/cpe-map.tsv"; do
  check "${_file}"
done

ADVANCED_ROOT="${OPENBSD_MAILSTACK_ADVANCED_RENDER_ROOT:-${PROJECT_ROOT}/.work/advanced/rootfs}"
ADVANCED_WORK_ROOT="$(dirname -- "${ADVANCED_ROOT}")"
SBOM_ROOT="${OPENBSD_MAILSTACK_ADVANCED_SBOM_ROOT:-${ADVANCED_WORK_ROOT}/sbom}"

check "${ADVANCED_WORK_ROOT}/README.txt"
check "${ADVANCED_WORK_ROOT}/advanced-gap-summary.txt"
check "${SBOM_ROOT}/README.txt"

if [ "${ENABLE_SURICATA}" = "yes" ]; then
  check "${ADVANCED_ROOT}/etc/suricata/suricata.yaml"
  check "${ADVANCED_ROOT}/etc/suricata/threshold.config"
  check "${ADVANCED_ROOT}/var/lib/suricata/rules/local.rules"
  check "${ADVANCED_ROOT}/usr/local/sbin/suricata-dump.ksh"
  check "${ADVANCED_ROOT}/usr/local/sbin/suricata-eve2pf.ksh"
fi

if [ "${ENABLE_BREVO_WEBHOOK}" = "yes" ]; then
  check "${ADVANCED_ROOT}/usr/local/sbin/brevo_webhook.py"
  check "${ADVANCED_ROOT}/etc/rc.d/brevo_webhook"
  check "${ADVANCED_ROOT}/etc/nginx/templates/${BREVO_WEBHOOK_NGINX_TEMPLATE_NAME}"
  check_contains "${ADVANCED_ROOT}/etc/nginx/templates/${BREVO_WEBHOOK_NGINX_TEMPLATE_NAME}" "/etc/nginx/templates/control-plane-allow.tmpl"
fi

if [ "${ENABLE_SOGO}" = "yes" ]; then
  check "${ADVANCED_ROOT}/etc/sogo/sogo.conf"
  check "${ADVANCED_ROOT}/etc/nginx/templates/openbsd-mailstack-sogo.locations.tmpl"
  check_contains "${ADVANCED_ROOT}/etc/nginx/templates/openbsd-mailstack-sogo.locations.tmpl" "/etc/nginx/templates/control-plane-allow.tmpl"
fi

[ "${FAIL}" -eq 0 ]
