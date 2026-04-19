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

FAIL=0
PASS=0
WARN=0

pass() { print -- "[$(timestamp)] PASS  $*"; PASS=$((PASS + 1)); }
warn() { print -- "[$(timestamp)] WARN  $*"; WARN=$((WARN + 1)); }
fail() { print -- "[$(timestamp)] FAIL  $*"; FAIL=$((FAIL + 1)); }

run_ok() {
  _label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass "${_label}"
  else
    fail "${_label}"
  fi
}

load_inputs() {
  load_project_config
  prompt_value "MAIL_HOSTNAME" "mail host" "mail.example.com"
  prompt_value "POSTFIX_DB_NAME" "postfix db name" "postfixadmin"
  prompt_value "MYSQL_ROOT_PASSWORD" "mysql root password"
  prompt_value "POSTFIX_VMAIL_BASE" "virtual mail base" "/var/vmail"
  prompt_value "INITIAL_MAILBOXES" "initial mailboxes" "postmaster@example.com abuse@example.com admin@example.net"
}

check_https() {
  if command_exists openssl; then
    if printf '' | openssl s_client -connect 127.0.0.1:443 -servername "${MAIL_HOSTNAME}" >/dev/null 2>&1; then
      pass "HTTPS TLS handshake succeeded on 127.0.0.1:443 for ${MAIL_HOSTNAME}"
    else
      fail "HTTPS TLS handshake failed on 127.0.0.1:443"
    fi
  else
    warn "openssl not available, skipping HTTPS TLS handshake"
  fi
}

check_mysql_mailbox_rows() {
  _count="$(mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -Nse "SELECT COUNT(*) FROM ${POSTFIX_DB_NAME}.mailbox;" 2>/dev/null || true)"
  case "${_count}" in
    ''|0)
      fail "mailbox table is empty"
      ;;
    *)
      pass "mailbox table contains ${_count} rows"
      ;;
  esac
}

check_maildirs() {
  for _mailbox in ${INITIAL_MAILBOXES}; do
    _domain="${_mailbox#*@}"
    _local="${_mailbox%@*}"
    _maildir="${POSTFIX_VMAIL_BASE}/${_domain}/${_local}"
    if [ -d "${_maildir}/cur" ] && [ -d "${_maildir}/new" ] && [ -d "${_maildir}/tmp" ]; then
      pass "maildir present: ${_maildir}"
    else
      fail "maildir missing: ${_maildir}"
    fi
  done
}

check_imap_tls() {
  if printf '' | openssl s_client -connect 127.0.0.1:993 -servername "${MAIL_HOSTNAME}" 2>/dev/null | grep -q 'BEGIN CERTIFICATE'; then
    pass "IMAPS TLS handshake succeeded on 127.0.0.1:993"
  else
    fail "IMAPS TLS handshake failed on 127.0.0.1:993"
  fi
}

check_smtp_banner() {
  if printf 'QUIT\r\n' | nc 127.0.0.1 25 2>/dev/null | grep -Eq '^220 '; then
    pass "SMTP banner present on 127.0.0.1:25"
  else
    fail "SMTP banner missing on 127.0.0.1:25"
  fi
}

main() {
  ensure_openbsd
  load_inputs
  run_ok "host service integrity verifier" ksh "${PROJECT_ROOT}/scripts/verify/verify-host-service-integrity.ksh"
  run_ok "postfix check" postfix check
  run_ok "nginx syntax check" nginx -t
  if command_exists doveconf; then
    run_ok "doveconf -n" doveconf -n
  else
    warn "doveconf not available"
  fi
  if command_exists rspamadm; then
    run_ok "rspamadm configtest" rspamadm configtest
  else
    warn "rspamadm not available"
  fi
  check_mysql_mailbox_rows
  check_maildirs
  check_https
  check_imap_tls
  check_smtp_banner

  print
  print -- "Functional mail lab summary"
  print -- "  PASS count : ${PASS}"
  print -- "  WARN count : ${WARN}"
  print -- "  FAIL count : ${FAIL}"
  print

  [ "${FAIL}" -eq 0 ]
}

main "$@"
