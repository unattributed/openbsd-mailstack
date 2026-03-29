#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"

advanced_load_config() {
  load_project_config
  : "${MAIL_HOSTNAME:=mail.example.com}"
  : "${MAIL_DOMAIN:=example.com}"
  : "${PUBLIC_IP:=192.0.2.10}"
  : "${ADMIN_EMAIL:=ops@example.invalid}"
  : "${ALERT_EMAIL:=${ADMIN_EMAIL}}"

  : "${ENABLE_SURICATA:=yes}"
  : "${SURICATA_INTERFACE:=em0}"
  : "${SURICATA_HOME_NETS:=127.0.0.0/8 10.44.0.0/24 192.168.1.0/24}"
  : "${SURICATA_CAPTURE_FILTER:=host ${PUBLIC_IP}}"
  : "${SURICATA_RULE_DIR:=/var/lib/suricata/rules}"
  : "${SURICATA_LOG_DIR:=/var/log/suricata}"
  : "${SURICATA_DASHBOARD_ROOT:=/var/www/htdocs/pf}"
  : "${SURICATA_EVE2PF_MODE:=watch}"
  : "${SURICATA_PF_TABLE_WATCH:=suricata_watch}"
  : "${SURICATA_PF_TABLE_BLOCK:=suricata_block}"
  : "${SURICATA_PF_TABLE_ALLOW:=suricata_allow}"

  : "${ENABLE_BREVO_WEBHOOK:=no}"
  : "${BREVO_WEBHOOK_LISTEN_ADDR:=127.0.0.1}"
  : "${BREVO_WEBHOOK_LISTEN_PORT:=9090}"
  : "${BREVO_WEBHOOK_URL_PATH:=/brevo/webhook}"
  : "${BREVO_WEBHOOK_ALERT_EMAIL:=${ALERT_EMAIL}}"
  : "${BREVO_WEBHOOK_STATE_PATH:=/var/db/brevo/brevo.json}"
  : "${BREVO_WEBHOOK_LOG_PATH:=/var/log/brevo-webhook.log}"
  : "${BREVO_WEBHOOK_NGINX_TEMPLATE_NAME:=openbsd-mailstack-brevo-webhook.locations.tmpl}"

  : "${ENABLE_SOGO:=no}"
  : "${SOGO_MAIL_DOMAIN:=${MAIL_DOMAIN}}"
  : "${SOGO_DB_NAME:=sogo}"
  : "${SOGO_DB_USER:=sogo}"
  : "${SOGO_DB_PASS:=change-me-sogo-password}"
  : "${SOGO_TIMEZONE:=UTC}"
  : "${SOGO_LANGUAGE:=English}"
  : "${SOGO_BASE_PATH:=/SOGo}"
  : "${SOGO_LISTEN_ADDR:=127.0.0.1}"
  : "${SOGO_LISTEN_PORT:=20000}"

  : "${ENABLE_SBOM:=yes}"
  : "${SBOM_SCANNER_MODE:=fallback}"
  : "${SBOM_REPORT_EMAIL:=${ALERT_EMAIL}}"
  : "${SBOM_REPORT_ROOT:=services/generated/sbom}"
  : "${SBOM_CRON_MINUTE:=40}"
  : "${SBOM_CRON_HOUR:=3}"
  : "${SBOM_NVD_API_KEY:=}"
  : "${SBOM_CVE_ENRICH_MITRE:=1}"
}

validate_advanced_inputs() {
  validate_yes_no "${ENABLE_SURICATA}" || die "ENABLE_SURICATA must be yes or no"
  validate_interface_name "${SURICATA_INTERFACE}" || die "SURICATA_INTERFACE is invalid"
  validate_absolute_path "${SURICATA_RULE_DIR}" || die "SURICATA_RULE_DIR must be absolute"
  validate_absolute_path "${SURICATA_LOG_DIR}" || die "SURICATA_LOG_DIR must be absolute"
  validate_yes_no "${ENABLE_BREVO_WEBHOOK}" || die "ENABLE_BREVO_WEBHOOK must be yes or no"
  validate_ipv4 "${BREVO_WEBHOOK_LISTEN_ADDR}" || validate_hostname "${BREVO_WEBHOOK_LISTEN_ADDR}" || die "BREVO_WEBHOOK_LISTEN_ADDR is invalid"
  validate_port "${BREVO_WEBHOOK_LISTEN_PORT}" || die "BREVO_WEBHOOK_LISTEN_PORT is invalid"
  validate_absolute_path "${BREVO_WEBHOOK_STATE_PATH}" || die "BREVO_WEBHOOK_STATE_PATH must be absolute"
  validate_absolute_path "${BREVO_WEBHOOK_LOG_PATH}" || die "BREVO_WEBHOOK_LOG_PATH must be absolute"
  validate_yes_no "${ENABLE_SOGO}" || die "ENABLE_SOGO must be yes or no"
  validate_domain "${SOGO_MAIL_DOMAIN}" || die "SOGO_MAIL_DOMAIN is invalid"
  validate_identifier "${SOGO_DB_NAME}" || die "SOGO_DB_NAME is invalid"
  validate_identifier "${SOGO_DB_USER}" || die "SOGO_DB_USER is invalid"
  validate_password_value "${SOGO_DB_PASS}" || die "SOGO_DB_PASS is invalid"
  validate_yes_no "${ENABLE_SBOM}" || die "ENABLE_SBOM must be yes or no"
  case "${SBOM_SCANNER_MODE}" in auto|fallback|mapped) ;; *) die "SBOM_SCANNER_MODE must be auto, fallback, or mapped" ;; esac
}
