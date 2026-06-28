#!/bin/ksh
set -u
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
REPO_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"
MODE="repo"
APPLY=0
PROBE_TO=""
EVIDENCE_DIR=""
PASS=0
FAIL=0

usage() {
  print -- "usage: $0 [--repo-only|--host] [--evidence-dir path]"
  print -- "       $0 --host --apply --probe-to address [--evidence-dir path]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-only) MODE="repo"; shift ;;
    --host) MODE="host"; shift ;;
    --apply) APPLY=1; shift ;;
    --probe-to) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; PROBE_TO="$2"; shift 2 ;;
    --evidence-dir) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; EVIDENCE_DIR="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) print -- "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ "${APPLY}" -eq 0 ] || [ "${MODE}" = "host" ] || {
  print -- "error: --apply requires --host" >&2
  exit 2
}
[ -z "${PROBE_TO}" ] || [ "${APPLY}" -eq 1 ] || {
  print -- "error: --probe-to requires --apply" >&2
  exit 2
}
case "${PROBE_TO}" in
  *[!A-Za-z0-9._+@-]*|*@*@*|@*|*@) print -- "error: invalid probe address" >&2; exit 2 ;;
esac

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
[ -n "${EVIDENCE_DIR}" ] || EVIDENCE_DIR="${TMPDIR:-/tmp}/openbsd-mailstack-evidence-${RUN_ID}"
mkdir -p "${EVIDENCE_DIR}"
chmod 0700 "${EVIDENCE_DIR}"
REPORT="${EVIDENCE_DIR}/regression.txt"
: > "${REPORT}"
chmod 0600 "${REPORT}"

emit() { print -- "$*" | tee -a "${REPORT}"; }
pass() { PASS=$((PASS + 1)); emit "PASS $*"; }
fail() { FAIL=$((FAIL + 1)); emit "FAIL $*"; }

have() { command -v "$1" >/dev/null 2>&1; }
priv() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    doas "$@"
  fi
}
check_command() {
  _label="$1"
  shift
  if "$@" >/dev/null 2>&1; then pass "${_label}"; else fail "${_label}"; fi
}
check_command_stdin_null() {
  _label="$1"
  shift
  if "$@" </dev/null >/dev/null 2>&1; then pass "${_label}"; else fail "${_label}"; fi
}
check_priv_command() {
  _label="$1"
  shift
  if priv "$@" >/dev/null 2>&1; then pass "${_label}"; else fail "${_label}"; fi
}
check_file() {
  _path="$1"
  if [ -f "${_path}" ]; then pass "file ${_path}"; else fail "file ${_path}"; fi
}
check_priv_path() {
  _path="$1"
  if priv test -e "${_path}"; then pass "path ${_path}"; else fail "path ${_path}"; fi
}
check_priv_metadata() {
  _path="$1"
  _expected="$2"
  _actual="$(priv stat -f '%Su:%Sg:%Lp' "${_path}" 2>/dev/null || print unavailable)"
  if [ "${_actual}" = "${_expected}" ]; then
    pass "metadata ${_path} ${_expected}"
  else
    fail "metadata ${_path} expected=${_expected} actual=${_actual}"
  fi
}
service_check() {
  _service="$1"
  if ! priv rcctl get "${_service}" >/dev/null 2>&1; then
    fail "service ${_service} configured"
  elif priv rcctl check "${_service}" >/dev/null 2>&1; then
    pass "service ${_service} healthy"
  else
    fail "service ${_service} healthy"
  fi
}
port_check() {
  _port="$1"
  if netstat -na -f inet 2>/dev/null | awk -v p="${_port}" '$0 ~ /LISTEN/ && $4 ~ ("\\." p "$") { found=1 } END { exit(found ? 0 : 1) }'; then
    pass "listener tcp/${_port}"
  else
    fail "listener tcp/${_port}"
  fi
}
loopback_only_check() {
  _port="$1"
  if netstat -na -f inet 2>/dev/null | awk -v p="${_port}" '
    $0 ~ /LISTEN/ && $4 ~ ("\\." p "$") {
      found=1
      if ($4 !~ /^127\./) bad=1
    }
    END { exit(found && !bad ? 0 : 1) }
  '; then
    pass "listener tcp/${_port} loopback-only"
  else
    fail "listener tcp/${_port} loopback-only"
  fi
}

repo_checks() {
  check_file "${REPO_ROOT}/docs/production-mail-blackbagsecurity.md"
  check_file "${REPO_ROOT}/docs/operations/09-openbsd-79-sdlc-maintenance.md"
  check_file "${REPO_ROOT}/config/production-regression.conf.example"
  check_file "${REPO_ROOT}/maint/openbsd-syspatch.ksh"
  check_file "${REPO_ROOT}/maint/openbsd-pkg-upgrade.ksh"
  if rg -n 'OPENBSD_VERSION="7\.8"|install78|site78|openbsd78' "${REPO_ROOT}" \
      --glob '!.git/**' --glob '!evidence/**' --glob '!production-regression.ksh' >/dev/null 2>&1; then
    fail "stale OpenBSD 7.8 baseline absent"
  else
    pass "stale OpenBSD 7.8 baseline absent"
  fi
  for _script in \
    "${REPO_ROOT}/maint/openbsd-syspatch.ksh" \
    "${REPO_ROOT}/maint/openbsd-pkg-upgrade.ksh" \
    "${REPO_ROOT}/maint/production-regression.ksh"; do
    check_command "ksh syntax ${_script#${REPO_ROOT}/}" ksh -n "${_script}"
  done
}

host_checks() {
  [ "$(uname -s)" = "OpenBSD" ] || { fail "host operating system OpenBSD"; return; }
  [ "$(sysctl -n kern.osrelease)" = "7.9" ] && pass "host release 7.9" || fail "host release 7.9"

  for _service in postfix dovecot rspamd nginx mysqld redis sogod php83_fpm clamd freshclam unbound vultr_ddns osmap_serve osmap_mailbox_helper; do
    service_check "${_service}"
  done
  for _service in smtpd nsd unwind; do
    if priv rcctl get "${_service}" >/dev/null 2>&1 && priv rcctl check "${_service}" >/dev/null 2>&1; then
      fail "service ${_service} inactive in observed production profile"
    else
      pass "service ${_service} inactive in observed production profile"
    fi
  done

  check_priv_command "Postfix configuration" postfix check
  check_priv_command "Dovecot configuration" doveconf -n
  check_priv_command "Rspamd configuration" rspamadm configtest
  check_priv_command "nginx configuration" nginx -t
  check_priv_command "PF configuration" pfctl -nf /etc/pf.conf
  check_priv_command "Unbound configuration" unbound-checkconf /var/unbound/etc/unbound.conf
  check_priv_command "ACME configuration" acme-client -n mail.blackbagsecurity.com
  check_priv_command "package database consistency" pkg_check -n -I

  for _port in 25 80 443 465 587 993 11334; do port_check "${_port}"; done
  loopback_only_check 8080
  check_command "SMTP loopback reachability" nc -z -w 5 127.0.0.1 25
  check_command "submission TLS reachability" nc -z -w 5 127.0.0.1 465
  check_command "IMAP TLS reachability" nc -z -w 5 127.0.0.1 993
  check_command_stdin_null "IMAP TLS handshake" openssl s_client -connect 127.0.0.1:993 -servername mail.blackbagsecurity.com -verify_return_error
  check_command_stdin_null "SMTP TLS handshake" openssl s_client -connect 127.0.0.1:465 -servername mail.blackbagsecurity.com -verify_return_error
  check_command_stdin_null "submission STARTTLS handshake" openssl s_client -connect 127.0.0.1:587 -servername mail.blackbagsecurity.com -verify_return_error -starttls smtp

  check_priv_metadata /etc/ssl/private/mail.blackbagsecurity.com.key root:wheel:600
  check_priv_path /etc/ssl/mail.blackbagsecurity.com.fullchain.pem
  check_priv_command "TLS certificate currently valid" openssl x509 -checkend 0 -noout -in /etc/ssl/mail.blackbagsecurity.com.fullchain.pem

  check_priv_metadata /usr/local/sbin/vultr_ddns_multi.py root:wheel:555
  check_priv_metadata /usr/local/sbin/vultr_ddns_service.sh root:wheel:555
  check_priv_metadata /etc/rc.d/vultr_ddns root:wheel:555

  check_priv_metadata /etc/osmap/osmap-serve.env root:osmaprt:640
  check_priv_metadata /etc/osmap/osmap-mailbox-helper.env root:vmail:640
  check_priv_metadata /var/run/osmap-auth _osmap:_osmap:660
  check_priv_metadata /var/run/osmap-userdb vmail:vmail:660
  check_priv_metadata /var/lib/osmap-helper/run/mailbox-helper.sock vmail:osmaprt:660
  check_priv_path /usr/local/bin/osmap
  check_priv_path /etc/rc.d/osmap_serve
  check_priv_path /etc/rc.d/osmap_mailbox_helper

  _code="$(curl -ksS -o /dev/null -w '%{http_code}' -H 'Host: mail.blackbagsecurity.com' https://127.0.0.1/healthz 2>/dev/null || print 000)"
  [ "${_code}" = "200" ] && pass "OSMAP GET /healthz status 200" || fail "OSMAP GET /healthz status=${_code}"
  _code="$(curl -ksS -o /dev/null -w '%{http_code}' -H 'Host: mail.blackbagsecurity.com' https://127.0.0.1/ 2>/dev/null || print 000)"
  [ "${_code}" = "303" ] && pass "OSMAP GET / status 303" || fail "OSMAP GET / status=${_code}"
  _code="$(curl -ksS -o /dev/null -w '%{http_code}' -H 'Host: mail.blackbagsecurity.com' https://127.0.0.1/login 2>/dev/null || print 000)"
  [ "${_code}" = "200" ] && pass "OSMAP GET /login status 200" || fail "OSMAP GET /login status=${_code}"
  _code="$(curl -ksS -o /dev/null -w '%{http_code}' -H 'Host: invalid.example' https://127.0.0.1/healthz 2>/dev/null || print 000)"
  [ "${_code}" = "421" ] && pass "OSMAP invalid Host status 421" || fail "OSMAP invalid Host status=${_code}"

  if [ "${APPLY}" -eq 1 ]; then
    [ -n "${PROBE_TO}" ] || { fail "apply mail probe recipient supplied"; return; }
    if {
      print -- "To: ${PROBE_TO}"
      print -- "Subject: openbsd-mailstack regression ${RUN_ID}"
      print
      print -- "Operator-authorized post-update mail-flow probe."
    } | /usr/sbin/sendmail -t; then
      pass "operator-authorized mail-flow probe queued"
    else
      fail "operator-authorized mail-flow probe queued"
    fi
  else
    pass "mail-flow mutation skipped without --apply"
  fi
}

write_checksum() {
  if have sha256; then
    (cd "${EVIDENCE_DIR}" && sha256 regression.txt) > "${EVIDENCE_DIR}/SHA256"
  elif have sha256sum; then
    (cd "${EVIDENCE_DIR}" && sha256sum regression.txt) > "${EVIDENCE_DIR}/SHA256"
  else
    emit "WARN checksum tool unavailable"
  fi
}

emit "schema=openbsd-mailstack-production-regression-v1"
emit "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
emit "mode=${MODE}"
emit "apply=${APPLY}"
if [ "${MODE}" = "repo" ]; then repo_checks; else host_checks; fi
emit "pass=${PASS}"
emit "fail=${FAIL}"
write_checksum
print -- "evidence=${EVIDENCE_DIR}"
[ "${FAIL}" -eq 0 ]
