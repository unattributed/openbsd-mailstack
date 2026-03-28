#!/bin/ksh
#
# scripts/phases/phase-02-verify.ksh
#
# Public Phase 02 verify script for openbsd-mailstack.
#

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

FAIL_COUNT=0
WARN_COUNT=0

pass() {
  print -- "[$(timestamp)] PASS  $*"
}

warn() {
  print -- "[$(timestamp)] WARN  $*"
  WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
  print -- "[$(timestamp)] FAIL  $*"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

collect_inputs() {
  load_project_config

  prompt_value "OPENBSD_VERSION" "Enter the supported OpenBSD version for this deployment" "7.8"
  prompt_value "PRIMARY_DOMAIN" "Enter the primary mail domain, example example.com"
  prompt_value "DOMAINS" "Enter the full hosted domain list separated by spaces"
  prompt_value "MYSQL_ROOT_PASSWORD" "Enter the MariaDB root password"
  prompt_value "MAILSTACK_DB_NAME" "Enter the shared mailstack database name" "mailstack"
  prompt_value "MAILSTACK_DB_USER" "Enter the shared mailstack database username" "mailstack"
  prompt_value "MAILSTACK_DB_PASSWORD" "Enter the shared mailstack database password"
  prompt_value "POSTFIXADMIN_DB_NAME" "Enter the PostfixAdmin database name" "postfixadmin"
  prompt_value "POSTFIXADMIN_DB_USER" "Enter the PostfixAdmin database username" "postfixadmin"
  prompt_value "POSTFIXADMIN_DB_PASSWORD" "Enter the PostfixAdmin database password"
  prompt_value "ROUNDCUBE_DB_NAME" "Enter the Roundcube database name" "roundcube"
  prompt_value "ROUNDCUBE_DB_USER" "Enter the Roundcube database username" "roundcube"
  prompt_value "ROUNDCUBE_DB_PASSWORD" "Enter the Roundcube database password"
}

validate_inputs() {
  if validate_domain "${PRIMARY_DOMAIN}"; then
    pass "PRIMARY_DOMAIN is valid: ${PRIMARY_DOMAIN}"
  else
    fail "PRIMARY_DOMAIN is invalid: ${PRIMARY_DOMAIN:-<empty>}"
  fi

  _domain_count=0
  for _domain in ${DOMAINS}; do
    _domain_count=$((_domain_count + 1))
    if validate_domain "${_domain}"; then
      pass "hosted domain is valid: ${_domain}"
    else
      fail "invalid hosted domain in DOMAINS list: ${_domain}"
    fi
  done
  [ "${_domain_count}" -gt 0 ] || fail "DOMAINS list is empty"

  for _name in MAILSTACK_DB_NAME MAILSTACK_DB_USER POSTFIXADMIN_DB_NAME POSTFIXADMIN_DB_USER ROUNDCUBE_DB_NAME ROUNDCUBE_DB_USER; do
    eval "_value=\${${_name}:-}"
    if validate_identifier "${_value}"; then
      pass "${_name} is valid: ${_value}"
    else
      fail "${_name} is invalid: ${_value:-<empty>}"
    fi
  done

  for _name in MYSQL_ROOT_PASSWORD MAILSTACK_DB_PASSWORD POSTFIXADMIN_DB_PASSWORD ROUNDCUBE_DB_PASSWORD; do
    eval "_value=\${${_name}:-}"
    if validate_password_value "${_value}"; then
      pass "${_name} is set and meets the minimum length requirement"
    else
      fail "${_name} is missing or too short"
    fi
  done
}

check_platform() {
  _os="$(uname -s 2>/dev/null || true)"
  _version="$(uname -r 2>/dev/null || true)"

  [ "${_os}" = "OpenBSD" ] && pass "operating system is OpenBSD" || fail "operating system is not OpenBSD, detected ${_os:-unknown}"
  [ "${_version}" = "${OPENBSD_VERSION}" ] && pass "OpenBSD version matches expected ${OPENBSD_VERSION}" || fail "OpenBSD version mismatch, expected ${OPENBSD_VERSION}, detected ${_version:-unknown}"
}

check_commands() {
  for cmd in uname awk grep sed rcctl pkg_info; do
    if command_exists "${cmd}"; then
      pass "required command present: ${cmd}"
    else
      fail "required command missing: ${cmd}"
    fi
  done
}

check_config_file_security() {
  _file="${PROJECT_ROOT}/config/secrets.conf"
  if [ -f "${_file}" ]; then
    pass "config/secrets.conf exists"
    _mode="$(stat -f '%OLp' "${_file}" 2>/dev/null || true)"
    [ "${_mode}" = "600" ] && pass "config/secrets.conf permissions are 600" || warn "config/secrets.conf permissions are ${_mode:-unknown}, expected 600"
  else
    warn "config/secrets.conf does not exist yet"
  fi
}

check_mariadb_state() {
  if pkg_info 2>/dev/null | grep -Eqi '^mariadb-server|^mariadb-client'; then
    pass "MariaDB package appears to be installed"
  else
    warn "MariaDB package does not appear to be installed yet"
  fi

  _svc="$(detect_mariadb_service_name || true)"
  if [ -n "${_svc}" ]; then
    pass "detected MariaDB service name: ${_svc}"
    if rcctl check "${_svc}" >/dev/null 2>&1; then
      pass "MariaDB service ${_svc} is running"
    else
      warn "MariaDB service ${_svc} exists but is not running"
    fi
  else
    warn "no MariaDB service name detected yet through rcctl"
  fi
}

print_result() {
  print
  print -- "Verification summary"
  print -- "  FAIL count : ${FAIL_COUNT}"
  print -- "  WARN count : ${WARN_COUNT}"
  print

  [ "${FAIL_COUNT}" -gt 0 ] && exit 1
  exit 0
}

main() {
  print_phase_header "PHASE-02" "mariadb baseline verification"
  collect_inputs
  validate_inputs
  check_platform
  check_commands
  check_config_file_security
  check_mariadb_state
  print_result
}

main "$@"
