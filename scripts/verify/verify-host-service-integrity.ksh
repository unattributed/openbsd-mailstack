#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing shared library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

FAIL_COUNT=0
WARN_COUNT=0
PASS_COUNT=0

pass() { print -- "[$(timestamp)] PASS  $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
warn() { print -- "[$(timestamp)] WARN  $*"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { print -- "[$(timestamp)] FAIL  $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

usage() {
  cat <<'EOF2'
Usage:
  ./scripts/verify/verify-host-service-integrity.ksh
EOF2
}

normalize_mode() {
  normalize_mode_octal "$1"
}

check_required_file() {
  _file="$1"
  _label="$2"
  if [ -f "${_file}" ]; then
    pass "${_label}: ${_file}"
  else
    fail "${_label} is missing: ${_file}"
  fi
}

check_required_directory() {
  _dir="$1"
  _label="$2"
  if [ -d "${_dir}" ]; then
    pass "${_label}: ${_dir}"
  else
    fail "${_label} is missing: ${_dir}"
  fi
}

check_required_secret_mode() {
  _file="$1"
  _label="$2"
  if [ ! -f "${_file}" ]; then
    fail "${_label} is missing: ${_file}"
    return 0
  fi
  _expected_mode="$(normalize_mode "$(runtime_secret_file_mode)")"
  _actual_mode="$(normalize_mode "$(file_mode_octal "${_file}")")"
  if [ -n "${_actual_mode}" ] && [ "${_actual_mode}" = "${_expected_mode}" ]; then
    pass "${_label} mode ok (${_actual_mode}): ${_file}"
  else
    fail "${_label} mode mismatch, expected ${_expected_mode}, got ${_actual_mode:-unknown}: ${_file}"
  fi
}

check_postfix_hash_maps_in_tree() {
  _root="$1"
  while IFS= read -r _rel || [ -n "${_rel}" ]; do
    [ -n "${_rel}" ] || continue
    _source_file="${_root%/}/${_rel}"
    _db_file="${_source_file}.db"
    check_required_file "${_source_file}" "postfix hash source"
    check_required_file "${_db_file}" "postfix hash map"
  done <<EOF2
$(postfix_hash_source_relative_paths)
EOF2
}

service_present() {
  _svc="$1"
  rcctl ls all 2>/dev/null | grep -qx "${_svc}"
}

service_running() {
  _svc="$1"
  rcctl check "${_svc}" >/dev/null 2>&1
}

check_service_if_present() {
  _svc="$1"
  if service_present "${_svc}"; then
    if service_running "${_svc}"; then
      pass "service running: ${_svc}"
    else
      fail "service not healthy: ${_svc}"
    fi
  else
    warn "service not present in rcctl inventory: ${_svc}"
  fi
}

listener_snapshot() {
  netstat -na -f inet 2>/dev/null | awk '$NF == "LISTEN" {print $4}'
}

listener_present_for_port() {
  _port="$1"
  listener_snapshot | grep -Eq "(^|[.:])${_port}$"
}

check_listener_ports_if_service_running() {
  _svc="$1"
  _label="$2"
  shift 2
  [ "$#" -gt 0 ] || return 0
  if ! service_present "${_svc}"; then
    warn "${_label} service not present in rcctl inventory: ${_svc}"
    return 0
  fi
  if ! service_running "${_svc}"; then
    warn "${_label} service is not running, listener check skipped: ${_svc}"
    return 0
  fi
  for _port in "$@"; do
    if listener_present_for_port "${_port}"; then
      pass "${_label} listener present on tcp/${_port}"
      return 0
    fi
  done
  fail "${_label} did not expose any expected listener ports: $*"
}

run_command_check() {
  _label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass "${_label}"
  else
    fail "${_label}"
  fi
}

lint_php_file_if_present() {
  _file="$1"
  _label="$2"
  if [ ! -f "${_file}" ]; then
    warn "${_label} is missing: ${_file}"
    return 0
  fi
  if command_exists php; then
    run_command_check "${_label} syntax ok" php -l "${_file}"
  elif command_exists php83; then
    run_command_check "${_label} syntax ok" php83 -l "${_file}"
  else
    warn "php cli not available, skipping ${_label} syntax check"
  fi
}

check_host_semantics() {
  if command_exists postfix; then
    run_command_check "postfix check passed" postfix check
  else
    warn "postfix command not available, skipping postfix check"
  fi

  if command_exists nginx; then
    run_command_check "nginx -t passed" nginx -t
  else
    warn "nginx command not available, skipping nginx syntax check"
  fi

  if command_exists doveconf; then
    run_command_check "doveconf -n passed" doveconf -n
  elif command_exists dovecot; then
    run_command_check "dovecot -n passed" dovecot -n
  else
    warn "dovecot configuration tool not available, skipping dovecot syntax check"
  fi

  if command_exists rspamadm; then
    run_command_check "rspamadm configtest passed" rspamadm configtest
  else
    warn "rspamadm not available, skipping rspamd configtest"
  fi

  if [ -f "/var/unbound/etc/unbound.conf" ] || [ -f "/var/unbound/etc/conf.d/mailstack-zones.conf" ]; then
    if command_exists unbound-checkconf; then
      run_command_check "unbound-checkconf passed" unbound-checkconf
    else
      warn "unbound-checkconf not available, skipping unbound syntax check"
    fi
  fi

  lint_php_file_if_present "/var/www/postfixadmin/config.local.php" "PostfixAdmin config"
  lint_php_file_if_present "/var/www/roundcubemail/config/config.inc.php" "Roundcube config"
}

check_mail_queue() {
  if command_exists mailq; then
    _queue_output="$(mailq 2>/dev/null || true)"
    if print -- "${_queue_output}" | grep -qi 'Mail queue is empty'; then
      pass "mail queue is empty"
    elif [ -n "${_queue_output}" ]; then
      warn "mail queue is not empty, review mailq output"
    else
      warn "mailq returned no output"
    fi
  else
    warn "mailq command is not available"
  fi
}

check_disk_usage() {
  _mount="$1"
  [ -d "${_mount}" ] || return 0
  _used="$(df -Pk "${_mount}" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
  if [ -z "${_used}" ]; then
    warn "unable to read disk usage for ${_mount}"
    return 0
  fi
  if [ "${_used}" -ge 90 ]; then
    fail "disk usage critical on ${_mount}: ${_used}%"
  elif [ "${_used}" -ge 80 ]; then
    warn "disk usage elevated on ${_mount}: ${_used}%"
  else
    pass "disk usage healthy on ${_mount}: ${_used}%"
  fi
}

check_pf_status() {
  if command_exists pfctl; then
    if pfctl -s info 2>/dev/null | grep -qi 'Status: Enabled'; then
      pass "pf is enabled"
    else
      warn "pfctl did not report an enabled firewall"
    fi
  else
    warn "pfctl not available, skipping firewall status check"
  fi
}

main() {
  if [ "${1:-}" = "--help" ]; then
    usage
    exit 0
  fi

  _os="$(uname -s 2>/dev/null || true)"
  if [ "${_os}" != "OpenBSD" ]; then
    warn "host integrity checks skipped because this is not OpenBSD, detected ${_os:-unknown}"
    print
    print -- "Host integrity summary"
    print -- "  PASS count : ${PASS_COUNT}"
    print -- "  WARN count : ${WARN_COUNT}"
    print -- "  FAIL count : ${FAIL_COUNT}"
    print
    exit 0
  fi

  require_command rcctl
  require_command df
  require_command netstat

  print_phase_header "HOST-INTEGRITY" "live host service and listener checks"

  check_required_file "/etc/postfix/main.cf" "installed postfix config"
  check_required_file "/etc/postfix/master.cf" "installed postfix master config"
  check_required_file "/etc/dovecot/dovecot.conf" "installed dovecot config"
  check_required_file "/etc/nginx/sites-available/main.conf" "installed nginx config"
  check_required_file "/etc/rspamd/local.d/worker-proxy.inc" "installed rspamd config"
  check_required_file "/var/www/postfixadmin/config.local.php" "installed postfixadmin config"
  check_required_file "/var/www/roundcubemail/config/config.inc.php" "installed roundcube config"
  check_required_directory "/var/vmail" "virtual mail root"

  while IFS= read -r _rel || [ -n "${_rel}" ]; do
    [ -n "${_rel}" ] || continue
    check_required_secret_mode "/${_rel}" "installed runtime secret"
  done <<EOF2
$(core_runtime_secret_relative_paths)
EOF2

  check_postfix_hash_maps_in_tree "/"
  check_required_secret_mode "/etc/postfix/sasl_passwd.db" "installed postfix sasl hash map"

  _db_service=""
  if _db_service="$(detect_mariadb_service_name 2>/dev/null)" && [ -n "${_db_service}" ]; then
    check_service_if_present "${_db_service}"
  else
    warn "could not determine the MariaDB rcctl service name"
  fi

  for _svc in postfix dovecot nginx rspamd redis redis_server clamd freshclam php83_fpm; do
    check_service_if_present "${_svc}"
  done

  check_listener_ports_if_service_running postfix "Postfix SMTP" 25 587 465
  check_listener_ports_if_service_running dovecot "Dovecot IMAP" 143 993
  check_listener_ports_if_service_running nginx "nginx web" 80 443
  check_listener_ports_if_service_running rspamd "Rspamd" 11332 11333 11334

  if [ -f "/etc/hostname.wg0" ]; then
    pass "WireGuard hostname file present: /etc/hostname.wg0"
  else
    warn "WireGuard hostname file not present: /etc/hostname.wg0"
  fi

  if [ -f "/etc/pf.anchors/openbsd-mailstack-selfhost" ]; then
    pass "PF anchor present: /etc/pf.anchors/openbsd-mailstack-selfhost"
  else
    warn "PF anchor not present: /etc/pf.anchors/openbsd-mailstack-selfhost"
  fi

  check_pf_status
  check_host_semantics
  check_mail_queue
  check_disk_usage "/"
  check_disk_usage "/var"
  check_disk_usage "/var/vmail"

  print
  print -- "Host integrity summary"
  print -- "  PASS count : ${PASS_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print

  [ "${FAIL_COUNT}" -eq 0 ]
}

main "$@"
