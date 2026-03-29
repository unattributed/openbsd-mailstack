#!/bin/ksh
set -e
set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing shared library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

SYSTEM_CONF="${PROJECT_ROOT}/config/system.conf"
RSPAMD_DIR="${PROJECT_ROOT}/services/rspamd"
POSTFIX_DIR="${PROJECT_ROOT}/services/postfix"

RSPAMD_PROXY_FRAGMENT="${RSPAMD_DIR}/worker-proxy.inc.example.generated"
RSPAMD_CONTROLLER_FRAGMENT="${RSPAMD_DIR}/worker-controller.inc.example.generated"
RSPAMD_REDIS_FRAGMENT="${RSPAMD_DIR}/redis.inc.example.generated"
RSPAMD_ANTIVIRUS_FRAGMENT="${RSPAMD_DIR}/antivirus.conf.example.generated"
POSTFIX_MILTER_FRAGMENT="${POSTFIX_DIR}/rspamd-milter.fragment.example.generated"
FILTERING_SUMMARY="${RSPAMD_DIR}/filtering-summary.txt"

SAVE_CONFIG="${SAVE_CONFIG:-no}"

collect_inputs() {
  load_project_config

  prompt_value "MAIL_HOSTNAME" "Enter the public mail hostname, example mail.example.com"
  prompt_value "PRIMARY_DOMAIN" "Enter the primary administrative domain, example example.com"
  prompt_value "RSPAMD_MILTER_BIND" "Enter the Rspamd milter bind value" "${RSPAMD_MILTER_BIND:-127.0.0.1:11332}"
  prompt_value "RSPAMD_NORMAL_BIND" "Enter the Rspamd normal worker bind value" "${RSPAMD_NORMAL_BIND:-127.0.0.1:11333}"
  prompt_value "RSPAMD_CONTROLLER_BIND" "Enter the Rspamd controller bind value" "${RSPAMD_CONTROLLER_BIND:-127.0.0.1:11334}"
  prompt_value "RSPAMD_REDIS_HOST" "Enter the Redis host for Rspamd" "${RSPAMD_REDIS_HOST:-127.0.0.1}"
  prompt_value "RSPAMD_REDIS_PORT" "Enter the Redis port for Rspamd" "${RSPAMD_REDIS_PORT:-6379}"
  prompt_value "RSPAMD_CLAMAV_ENABLED" "Enable ClamAV integration, yes or no" "${RSPAMD_CLAMAV_ENABLED:-yes}"
}

validate_inputs() {
  validate_hostname "${MAIL_HOSTNAME}" || die "invalid MAIL_HOSTNAME: ${MAIL_HOSTNAME}"
  validate_domain "${PRIMARY_DOMAIN}" || die "invalid PRIMARY_DOMAIN: ${PRIMARY_DOMAIN}"
  validate_host_port "${RSPAMD_MILTER_BIND}" || die "invalid RSPAMD_MILTER_BIND: ${RSPAMD_MILTER_BIND}"
  validate_host_port "${RSPAMD_NORMAL_BIND}" || die "invalid RSPAMD_NORMAL_BIND: ${RSPAMD_NORMAL_BIND}"
  validate_host_port "${RSPAMD_CONTROLLER_BIND}" || die "invalid RSPAMD_CONTROLLER_BIND: ${RSPAMD_CONTROLLER_BIND}"
  validate_hostname "${RSPAMD_REDIS_HOST}" || [ "${RSPAMD_REDIS_HOST}" = "127.0.0.1" ] || die "invalid RSPAMD_REDIS_HOST: ${RSPAMD_REDIS_HOST}"
  validate_numeric_port "${RSPAMD_REDIS_PORT}" || die "invalid RSPAMD_REDIS_PORT: ${RSPAMD_REDIS_PORT}"
  validate_yes_no "${RSPAMD_CLAMAV_ENABLED}" || die "RSPAMD_CLAMAV_ENABLED must be yes or no"
}

save_configs_if_requested() {
  [ "${SAVE_CONFIG}" = "yes" ] || return 0
  mkdir -p "${CONFIG_DIR}"

  write_named_config "${SYSTEM_CONF}"     "OPENBSD_VERSION" "${OPENBSD_VERSION:-7.8}"     "MAIL_HOSTNAME" "${MAIL_HOSTNAME}"     "PRIMARY_DOMAIN" "${PRIMARY_DOMAIN}"     "ADMIN_EMAIL" "${ADMIN_EMAIL:-ops@${PRIMARY_DOMAIN}}"     "PUBLIC_IPV4" "${PUBLIC_IPV4:-203.0.113.10}"     "TIMEZONE" "${TIMEZONE:-UTC}"     "TLS_CERT_MODE" "${TLS_CERT_MODE:-single_hostname}"     "TLS_ACME_PROVIDER" "${TLS_ACME_PROVIDER:-acme-client}"     "TLS_CERT_FQDN" "${TLS_CERT_FQDN:-${MAIL_HOSTNAME}}"     "TLS_CERT_PATH_FULLCHAIN" "${TLS_CERT_PATH_FULLCHAIN:-/etc/ssl/${MAIL_HOSTNAME}.fullchain.pem}"     "TLS_CERT_PATH_KEY" "${TLS_CERT_PATH_KEY:-/etc/ssl/private/${MAIL_HOSTNAME}.key}"     "RSPAMD_CONTROLLER_BIND" "${RSPAMD_CONTROLLER_BIND}"     "RSPAMD_MILTER_BIND" "${RSPAMD_MILTER_BIND}"     "RSPAMD_NORMAL_BIND" "${RSPAMD_NORMAL_BIND}"     "RSPAMD_REDIS_HOST" "${RSPAMD_REDIS_HOST}"     "RSPAMD_REDIS_PORT" "${RSPAMD_REDIS_PORT}"     "RSPAMD_CLAMAV_ENABLED" "${RSPAMD_CLAMAV_ENABLED}"
}

check_commands() {
  require_command mkdir
  require_command cat
  require_command grep
  require_command awk
  require_command rspamadm
  require_command rspamd
}

generate_files() {
  mkdir -p "${RSPAMD_DIR}" "${POSTFIX_DIR}"

  cat > "${RSPAMD_PROXY_FRAGMENT}" <<EOF
bind_socket = "${RSPAMD_MILTER_BIND}";
milter = yes;
timeout = 120s;
upstream "local" {
  default = yes;
  self_scan = no;
}
EOF

  cat > "${RSPAMD_CONTROLLER_FRAGMENT}" <<EOF
bind_socket = "${RSPAMD_CONTROLLER_BIND}";
secure_ip = "127.0.0.1";
EOF

  cat > "${RSPAMD_REDIS_FRAGMENT}" <<EOF
servers = "${RSPAMD_REDIS_HOST}:${RSPAMD_REDIS_PORT}";
expand_keys = true;
EOF

  cat > "${RSPAMD_ANTIVIRUS_FRAGMENT}" <<EOF
clamav {
  enabled = ${RSPAMD_CLAMAV_ENABLED};
  symbol = "CLAM_VIRUS";
  type = "clamav";
}
EOF

  cat > "${POSTFIX_MILTER_FRAGMENT}" <<EOF
smtpd_milters = inet:${RSPAMD_MILTER_BIND#*:}
non_smtpd_milters = inet:${RSPAMD_MILTER_BIND#*:}
milter_default_action = accept
milter_protocol = 6
EOF

  cat > "${FILTERING_SUMMARY}" <<EOF
Phase 07 filtering summary
MAIL_HOSTNAME: ${MAIL_HOSTNAME}
PRIMARY_DOMAIN: ${PRIMARY_DOMAIN}
RSPAMD_MILTER_BIND: ${RSPAMD_MILTER_BIND}
RSPAMD_NORMAL_BIND: ${RSPAMD_NORMAL_BIND}
RSPAMD_CONTROLLER_BIND: ${RSPAMD_CONTROLLER_BIND}
RSPAMD_REDIS_HOST: ${RSPAMD_REDIS_HOST}
RSPAMD_REDIS_PORT: ${RSPAMD_REDIS_PORT}
RSPAMD_CLAMAV_ENABLED: ${RSPAMD_CLAMAV_ENABLED}
EOF
}

main() {
  print_phase_header "PHASE-07" "filtering and anti-abuse"
  collect_inputs
  validate_inputs
  save_configs_if_requested
  check_commands
  generate_files
  log_info "phase 07 filtering and anti-abuse completed successfully"
  log_info "next step: run ./scripts/phases/phase-07-verify.ksh"
}

main "$@"
