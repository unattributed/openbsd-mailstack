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


for _file in   "${PROJECT_ROOT}/config/suricata.conf.example"   "${PROJECT_ROOT}/config/brevo-webhook.conf.example"   "${PROJECT_ROOT}/config/sogo.conf.example"   "${PROJECT_ROOT}/config/sbom.conf.example"   "${PROJECT_ROOT}/scripts/lib/advanced-gap-rollout.ksh"   "${PROJECT_ROOT}/scripts/install/render-advanced-gap-configs.ksh"   "${PROJECT_ROOT}/scripts/install/install-advanced-gap-assets.ksh"   "${PROJECT_ROOT}/scripts/ops/suricata-dump.ksh"   "${PROJECT_ROOT}/scripts/ops/suricata-eve2pf.ksh"   "${PROJECT_ROOT}/scripts/ops/sbom-daily-scan.ksh"   "${PROJECT_ROOT}/services/suricata/etc/suricata/suricata.yaml.template"   "${PROJECT_ROOT}/services/brevo/usr/local/sbin/brevo_webhook.py.template"   "${PROJECT_ROOT}/services/sogo/etc/sogo/sogo.conf.template"   "${PROJECT_ROOT}/services/sbom/components/cpe-map.tsv"
do
  check "${_file}"
done

check "${PROJECT_ROOT}/services/generated/rootfs/etc/suricata/suricata.yaml"
check "${PROJECT_ROOT}/services/generated/rootfs/usr/local/sbin/brevo_webhook.py"
check "${PROJECT_ROOT}/services/generated/rootfs/etc/sogo/sogo.conf"
check "${PROJECT_ROOT}/services/generated/advanced-gap-summary.txt"

[ "${FAIL}" -eq 0 ]

check_contains "${PROJECT_ROOT}/services/generated/rootfs/etc/nginx/templates/openbsd-mailstack-brevo-webhook.locations.tmpl" "/etc/nginx/templates/control-plane-allow.tmpl"
check_contains "${PROJECT_ROOT}/services/generated/rootfs/etc/nginx/templates/openbsd-mailstack-sogo.locations.tmpl" "/etc/nginx/templates/control-plane-allow.tmpl"
