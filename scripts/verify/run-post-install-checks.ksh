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
CORE_RENDER_ROOT="$(core_runtime_render_root)"

CHECK_REPO=1
CHECK_HOST=1
FAIL_COUNT=0
WARN_COUNT=0
PASS_COUNT=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/verify/run-post-install-checks.ksh [--repo-only|--host-only|--help]
EOF
}

pass() { print -- "[$(timestamp)] PASS  $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
warn() { print -- "[$(timestamp)] WARN  $*"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { print -- "[$(timestamp)] FAIL  $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --repo-only)
        CHECK_REPO=1
        CHECK_HOST=0
        shift
        ;;
      --host-only)
        CHECK_REPO=0
        CHECK_HOST=1
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done
}

check_file_exists() {
  _file="$1"
  _label="$2"
  if [ -f "${_file}" ]; then
    pass "${_label}: ${_file}"
  else
    fail "${_label} is missing: ${_file}"
  fi
}

warn_if_missing() {
  _file="$1"
  _label="$2"
  if [ -f "${_file}" ]; then
    pass "${_label}: ${_file}"
  else
    warn "${_label} is missing: ${_file}"
  fi
}

check_secret_mode() {
  _file="$1"
  _label="$2"
  if [ ! -f "${_file}" ]; then
    warn "${_label} is missing: ${_file}"
    return 0
  fi
  _expected_mode="$(normalize_mode_octal "$(runtime_secret_file_mode)")"
  _actual_mode="$(normalize_mode_octal "$(file_mode_octal "${_file}")")"
  if [ -n "${_actual_mode}" ] && [ "${_actual_mode}" = "${_expected_mode}" ]; then
    pass "${_label} mode ok (${_actual_mode}): ${_file}"
  else
    fail "${_label} mode mismatch, expected ${_expected_mode}, got ${_actual_mode:-unknown}: ${_file}"
  fi
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

check_required_secret_mode() {
  _file="$1"
  _label="$2"
  if [ ! -f "${_file}" ]; then
    fail "${_label} is missing: ${_file}"
    return 0
  fi
  _expected_mode="$(normalize_mode_octal "$(runtime_secret_file_mode)")"
  _actual_mode="$(normalize_mode_octal "$(file_mode_octal "${_file}")")"
  if [ -n "${_actual_mode}" ] && [ "${_actual_mode}" = "${_expected_mode}" ]; then
    pass "${_label} mode ok (${_actual_mode}): ${_file}"
  else
    fail "${_label} mode mismatch, expected ${_expected_mode}, got ${_actual_mode:-unknown}: ${_file}"
  fi
}

check_postfix_hash_maps_in_tree() {
  _root="$1"
  _label_prefix="$2"
  while IFS= read -r _rel || [ -n "${_rel}" ]; do
    [ -n "${_rel}" ] || continue
    _source_file="${_root%/}/${_rel}"
    _db_file="${_source_file}.db"
    check_required_file "${_source_file}" "${_label_prefix} postfix hash source"
    check_required_file "${_db_file}" "${_label_prefix} postfix hash map"
  done <<EOF
$(postfix_hash_source_relative_paths)
EOF
}

check_repo_state() {
  print_phase_header "POST-INSTALL" "repo checks"

  check_file_exists "${PROJECT_ROOT}/scripts/install/render-core-runtime-configs.ksh" "render helper present"
  check_file_exists "${PROJECT_ROOT}/scripts/install/install-core-runtime-configs.ksh" "install helper present"
  check_file_exists "${PROJECT_ROOT}/scripts/install/run-phase-sequence.ksh" "phase sequence runner present"
  check_file_exists "${PROJECT_ROOT}/scripts/verify/verify-core-runtime-assets.ksh" "core runtime verifier present"
  check_file_exists "${CORE_RENDER_ROOT}/etc/postfix/main.cf" "live rendered postfix config present"
  check_file_exists "${CORE_RENDER_ROOT}/etc/dovecot/dovecot.conf" "live rendered dovecot config present"
  check_file_exists "${CORE_RENDER_ROOT}/etc/nginx/sites-available/main.conf" "live rendered nginx config present"
  check_file_exists "${CORE_RENDER_ROOT}/etc/rspamd/local.d/worker-proxy.inc" "live rendered rspamd config present"
  check_file_exists "${CORE_RENDER_ROOT}/var/www/postfixadmin/config.local.php" "live rendered postfixadmin config present"
  while IFS= read -r _rel || [ -n "${_rel}" ]; do
    [ -n "${_rel}" ] || continue
    check_secret_mode "${CORE_RENDER_ROOT%/}/${_rel}" "live runtime secret"
  done <<EOF
$(core_runtime_secret_relative_paths)
EOF

  if [ -n "$(find_postmap_command)" ]; then
    check_postfix_hash_maps_in_tree "${CORE_RENDER_ROOT}" "live runtime"
    check_required_secret_mode "${CORE_RENDER_ROOT%/}/etc/postfix/sasl_passwd.db" "live postfix sasl hash map"
  else
    warn "postmap not available, skipping live postfix hash map verification in ${CORE_RENDER_ROOT}"
  fi

  _phase=0
  while [ "${_phase}" -le 10 ]; do
    _id="$(printf '%02d' "${_phase}")"
    warn_if_missing "${PROJECT_ROOT}/scripts/phases/phase-${_id}-apply.ksh" "phase ${_id} apply script"
    warn_if_missing "${PROJECT_ROOT}/scripts/phases/phase-${_id}-verify.ksh" "phase ${_id} verify script"
    _phase=$(( _phase + 1 ))
  done

  load_project_config || true

  if [ -n "${MAIL_HOSTNAME:-}" ]; then
    validate_hostname "${MAIL_HOSTNAME}" && pass "MAIL_HOSTNAME is valid: ${MAIL_HOSTNAME}" || fail "MAIL_HOSTNAME is invalid: ${MAIL_HOSTNAME}"
  else
    warn "MAIL_HOSTNAME was not loaded from operator inputs"
  fi

  if [ -n "${PRIMARY_DOMAIN:-}" ]; then
    validate_domain "${PRIMARY_DOMAIN}" && pass "PRIMARY_DOMAIN is valid: ${PRIMARY_DOMAIN}" || fail "PRIMARY_DOMAIN is invalid: ${PRIMARY_DOMAIN}"
  else
    warn "PRIMARY_DOMAIN was not loaded from operator inputs"
  fi

  if [ -n "${ADMIN_EMAIL:-}" ]; then
    validate_email "${ADMIN_EMAIL}" && pass "ADMIN_EMAIL is valid: ${ADMIN_EMAIL}" || fail "ADMIN_EMAIL is invalid: ${ADMIN_EMAIL}"
  else
    warn "ADMIN_EMAIL was not loaded from operator inputs"
  fi
}

service_present() {
  _svc="$1"
  rcctl ls all 2>/dev/null | grep -qx "${_svc}"
}

check_service_if_present() {
  _svc="$1"
  if service_present "${_svc}"; then
    if rcctl check "${_svc}" >/dev/null 2>&1; then
      pass "service running: ${_svc}"
    else
      fail "service not healthy: ${_svc}"
    fi
  else
    warn "service not present in rcctl inventory: ${_svc}"
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

check_host_state() {
  print_phase_header "POST-INSTALL" "host checks"

  _os="$(uname -s 2>/dev/null || true)"
  if [ "${_os}" != "OpenBSD" ]; then
    warn "host checks skipped because this is not OpenBSD, detected ${_os:-unknown}"
    return 0
  fi

  require_command rcctl
  require_command df

  warn_if_missing "/etc/postfix/main.cf" "installed postfix config"
  warn_if_missing "/etc/dovecot/dovecot.conf" "installed dovecot config"
  warn_if_missing "/etc/nginx/sites-available/main.conf" "installed nginx config"
  warn_if_missing "/etc/rspamd/local.d/worker-proxy.inc" "installed rspamd config"
  warn_if_missing "/var/www/postfixadmin/config.local.php" "installed postfixadmin config"
  while IFS= read -r _rel || [ -n "${_rel}" ]; do
    [ -n "${_rel}" ] || continue
    check_secret_mode "/${_rel}" "installed runtime secret"
  done <<EOF
$(core_runtime_secret_relative_paths)
EOF
  check_postfix_hash_maps_in_tree "/" "installed"
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

  check_disk_usage "/"
  check_disk_usage "/var"
  check_disk_usage "/var/vmail"
}

main() {
  parse_args "$@"

  [ "${CHECK_REPO}" -eq 1 ] && check_repo_state
  [ "${CHECK_HOST}" -eq 1 ] && check_host_state

  print
  print -- "Post-install summary"
  print -- "  PASS count : ${PASS_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print

  [ "${FAIL_COUNT}" -eq 0 ]
}

main "$@"
