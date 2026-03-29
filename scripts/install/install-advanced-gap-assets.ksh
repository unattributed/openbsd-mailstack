#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${PROJECT_ROOT}/scripts/lib/advanced-gap-rollout.ksh"

MODE="${1:---dry-run}"
case "${MODE}" in --dry-run|--apply) ;; *) die "usage: $0 --dry-run | --apply" ;; esac

advanced_load_config
validate_advanced_inputs
ksh "${PROJECT_ROOT}/scripts/install/render-advanced-gap-configs.ksh"

as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else doas -n "$@"; fi
}
install_file() {
  _src="$1"; _dst="$2"
  if [ "${MODE}" = "--dry-run" ]; then
    print -- "DRY-RUN install ${_src} -> ${_dst}"
  else
    as_root mkdir -p "$(dirname -- "${_dst}")"
    as_root cp -p "${_src}" "${_dst}"
  fi
}
GEN_ROOT="${PROJECT_ROOT}/services/generated/rootfs"
if [ "${ENABLE_SURICATA}" = "yes" ]; then
  install_file "${GEN_ROOT}/etc/suricata/suricata.yaml" "/etc/suricata/suricata.yaml"
  install_file "${GEN_ROOT}/etc/suricata/threshold.config" "/etc/suricata/threshold.config"
  install_file "${GEN_ROOT}/var/lib/suricata/rules/local.rules" "${SURICATA_RULE_DIR}/local.rules"
  install_file "${GEN_ROOT}/usr/local/sbin/suricata-dump.ksh" "/usr/local/sbin/suricata-dump.ksh"
  install_file "${GEN_ROOT}/usr/local/sbin/suricata-eve2pf.ksh" "/usr/local/sbin/suricata-eve2pf.ksh"
fi
if [ "${ENABLE_BREVO_WEBHOOK}" = "yes" ]; then
  install_file "${GEN_ROOT}/usr/local/sbin/brevo_webhook.py" "/usr/local/sbin/brevo_webhook.py"
  install_file "${GEN_ROOT}/etc/rc.d/brevo_webhook" "/etc/rc.d/brevo_webhook"
  install_file "${GEN_ROOT}/etc/nginx/templates/${BREVO_WEBHOOK_NGINX_TEMPLATE_NAME}" "/etc/nginx/templates/${BREVO_WEBHOOK_NGINX_TEMPLATE_NAME}"
fi
if [ "${ENABLE_SOGO}" = "yes" ]; then
  install_file "${GEN_ROOT}/etc/sogo/sogo.conf" "/etc/sogo/sogo.conf"
  install_file "${GEN_ROOT}/etc/nginx/templates/openbsd-mailstack-sogo.locations.tmpl" "/etc/nginx/templates/openbsd-mailstack-sogo.locations.tmpl"
fi
if [ "${ENABLE_SBOM}" = "yes" ]; then
  for _script in sbom-source-spdx.ksh sbom-host-inventory.ksh sbom-scan-openbsd-fallback.ksh sbom-scan-nvd-mapped.ksh sbom-daily-scan.ksh; do
    install_file "${PROJECT_ROOT}/scripts/ops/${_script}" "/usr/local/sbin/${_script}"
  done
fi
log_info "advanced optional assets install ${MODE#--} completed"
