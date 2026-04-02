#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
NETWORK_LIB="${PROJECT_ROOT}/scripts/lib/network-exposure.ksh"
ADVANCED_LIB="${PROJECT_ROOT}/scripts/lib/advanced-gap-rollout.ksh"
OPERATIONS_LIB="${PROJECT_ROOT}/scripts/lib/operations-phase-profiles.ksh"
BACKUP_DR_LIB="${PROJECT_ROOT}/scripts/lib/backup-dr.ksh"
ADVANCED_PHASE_LIB="${PROJECT_ROOT}/scripts/lib/advanced-phase-profiles.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing shared library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"
[ -f "${NETWORK_LIB}" ] && . "${NETWORK_LIB}"
[ -f "${ADVANCED_LIB}" ] && . "${ADVANCED_LIB}"
[ -f "${OPERATIONS_LIB}" ] && . "${OPERATIONS_LIB}"
[ -f "${BACKUP_DR_LIB}" ] && . "${BACKUP_DR_LIB}"
[ -f "${ADVANCED_PHASE_LIB}" ] && . "${ADVANCED_PHASE_LIB}"

FAIL=0

pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=1; }

check_file() {
  _file="$1"
  _label="$2"
  if [ -f "${_file}" ]; then
    pass "${_label}: ${_file}"
  else
    fail "${_label} missing: ${_file}"
  fi
}

check_regex() {
  _file="$1"
  _regex="$2"
  _label="$3"
  if [ ! -f "${_file}" ]; then
    fail "${_label} missing: ${_file}"
    return 0
  fi
  if grep -Eq "${_regex}" "${_file}"; then
    pass "${_label}"
  else
    fail "${_label} pattern not found in ${_file}"
  fi
}

check_no_upper_placeholders() {
  _file="$1"
  _label="$2"
  if [ ! -f "${_file}" ]; then
    fail "${_label} missing: ${_file}"
    return 0
  fi
  if grep -Eq '__[A-Z0-9][A-Z0-9_]*__' "${_file}"; then
    fail "${_label} still contains unresolved uppercase placeholders: ${_file}"
  else
    pass "${_label} has no unresolved uppercase placeholders"
  fi
}

check_mail_root() {
  _root="$1"
  _label="$2"
  [ -d "${_root}" ] || {
    fail "${_label} root missing: ${_root}"
    return 0
  }

  check_regex "${_root}/etc/postfix/main.cf" 'virtual_mailbox_domains *= *mysql:/etc/postfix/mysql_virtual_domains_maps\.cf' "${_label} postfix mailbox domain wiring"
  check_regex "${_root}/etc/postfix/main.cf" 'virtual_transport *= *lmtp:unix:private/dovecot-lmtp' "${_label} postfix dovecot lmtp wiring"
  check_regex "${_root}/etc/postfix/master.cf" '(^|[[:space:]])(127\.0\.0\.1:587|submission)[[:space:]]+inet' "${_label} postfix submission service"
  check_regex "${_root}/etc/dovecot/dovecot.conf" 'protocols *= *imap lmtp' "${_label} dovecot protocol set"
  check_regex "${_root}/etc/dovecot/local.conf" 'mail_location *= *maildir:' "${_label} dovecot maildir location"
  check_regex "${_root}/etc/nginx/sites-available/main-ssl.conf" 'include /etc/nginx/templates/ssl\.tmpl;' "${_label} nginx ssl template include"
  check_regex "${_root}/etc/rspamd/local.d/worker-proxy.inc" 'milter *= *yes;' "${_label} rspamd proxy milter enabled"
  check_regex "${_root}/etc/rspamd/local.d/worker-controller.inc" 'bind_socket *= *"' "${_label} rspamd controller bind configured"
  check_regex "${_root}/var/www/postfixadmin/config.local.php" "\$CONF\['configured'\] = true;" "${_label} postfixadmin configured flag"
  check_regex "${_root}/var/www/roundcubemail/config/config.inc.php" "\$config\['default_host'\] = 'ssl://" "${_label} roundcube default host configured"

  check_no_upper_placeholders "${_root}/etc/postfix/main.cf" "${_label} postfix main.cf"
  check_no_upper_placeholders "${_root}/etc/dovecot/local.conf" "${_label} dovecot local.conf"
  check_no_upper_placeholders "${_root}/etc/nginx/sites-available/main-ssl.conf" "${_label} nginx main-ssl.conf"
}

check_network_root() {
  _root="$1"
  _label="$2"
  [ -d "${_root}" ] || {
    fail "${_label} root missing: ${_root}"
    return 0
  }

  check_regex "${_root}/etc/pf.conf" 'anchor "openbsd-mailstack-selfhost"' "${_label} pf anchor include"
  check_regex "${_root}/etc/hostname.wg0" '^inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ [0-9]+ NONE' "${_label} wireguard hostname stanza"
  check_regex "${_root}/var/unbound/etc/unbound.conf" 'include: "/var/unbound/etc/conf\.d/\*\.conf"' "${_label} unbound include path"

  check_no_upper_placeholders "${_root}/etc/pf.conf" "${_label} pf.conf"
  check_no_upper_placeholders "${_root}/var/unbound/etc/unbound.conf" "${_label} unbound.conf"
}

check_monitoring_examples() {
  _root="$1"
  _label="$2"
  [ -d "${_root}" ] || {
    fail "${_label} root missing: ${_root}"
    return 0
  }
  check_regex "${_root}/etc/newsyslog.phase14-monitoring.conf" '/var/log/openbsd-mailstack-monitor\.log' "${_label} newsyslog monitoring log path"
  check_no_upper_placeholders "${_root}/etc/newsyslog.phase14-monitoring.conf" "${_label} newsyslog phase14 config"
}

check_optional_root_if_present() {
  _root="$1"
  _label="$2"
  if [ -d "${_root}" ]; then
    check_file "${_root}" "${_label} root present"
  else
    pass "${_label} root not present, skipping optional live checks"
  fi
}

main() {
  _tracked_root="$(core_runtime_example_root)"
  _live_core_root="$(core_runtime_render_root)"
  _live_network_root="$(network_render_root 2>/dev/null || print -- "${PROJECT_ROOT}/.work/network-exposure/rootfs")"

  print_phase_header "VERIFY" "rendered config integrity"

  check_mail_root "${_tracked_root}" "tracked sanitized core example"
  check_network_root "${_tracked_root}" "tracked sanitized network example"
  check_monitoring_examples "${_tracked_root}" "tracked sanitized monitoring example"

  if [ -d "${_live_core_root}" ]; then
    check_mail_root "${_live_core_root}" "live core render"
  else
    pass "live core render not present, skipping live core checks"
  fi

  if [ -d "${_live_network_root}" ]; then
    check_network_root "${_live_network_root}" "live network render"
  else
    pass "live network render not present, skipping live network checks"
  fi

  [ "${FAIL}" -eq 0 ]
}

main "$@"
