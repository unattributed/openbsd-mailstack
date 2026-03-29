#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"
umask 077

LOG_TAG="openbsd_mailstack_sshd_watchdog"
CHECK_ONLY=0
VERBOSE=0
BIND_IP="${SSHD_BIND_IP:-}"
HEALTH_REASON=""

usage() {
  cat <<'EOF'
usage: sshd-watchdog.ksh [--check-only] [--verbose] [--bind-ip <ipv4>]
EOF
}

ts() { date "+%Y-%m-%dT%H:%M:%S%z"; }

log_msg() {
  logger -t "${LOG_TAG}" -- "$*"
  if [ "${VERBOSE}" -eq 1 ]; then
    print -- "[$(ts)] $*"
  fi
}

die() { print -- "error: $*" >&2; exit 1; }
need_root() { [ "$(id -u)" -eq 0 ] || die "must run as root"; }

add_reason() {
  if [ -z "${HEALTH_REASON}" ]; then
    HEALTH_REASON="$1"
  else
    HEALTH_REASON="${HEALTH_REASON}; $1"
  fi
}

extract_bind_ip_from_sshd() {
  sshd -T 2>/dev/null | awk '
    $1 == "listenaddress" {
      addr = $2
      gsub(/^\[/, "", addr)
      sub(/\]$/, "", addr)
      sub(/\]:[0-9]+$/, "", addr)
      sub(/:[0-9]+$/, "", addr)
      if (addr ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ && addr != "0.0.0.0") {
        print addr
        exit
      }
    }
  '
}

validate_ipv4() {
  print -- "$1" | awk -F'.' '
    NF != 4 { exit 1 }
    { for (i = 1; i <= 4; i++) { if ($i !~ /^[0-9]+$/) exit 1; if ($i < 0 || $i > 255) exit 1 } }
  '
}

bind_ip_present() {
  ip="$1"
  ifconfig | awk -v ip="${ip}" '$1 == "inet" && $2 == ip { found = 1 } END { exit(found ? 0 : 1) }'
}

sshd_listening_on_ip22() {
  ip="$1"
  netstat -an -f inet | awk -v local="${ip}.22" '$1 ~ /^tcp/ && $4 == local && $NF == "LISTEN" { found = 1 } END { exit(found ? 0 : 1) }'
}

probe_health() {
  ip="$1"
  HEALTH_REASON=""
  rcctl check sshd >/dev/null 2>&1 || add_reason "rcctl check sshd failed"
  if [ -z "${ip}" ]; then
    add_reason "no explicit IPv4 listenaddress found"
  else
    bind_ip_present "${ip}" || add_reason "bind IP ${ip} not present on local interfaces"
    sshd_listening_on_ip22 "${ip}" || add_reason "no LISTEN socket on ${ip}:22"
  fi
  [ -z "${HEALTH_REASON}" ]
}

restart_and_reprobe() {
  ip="$1"
  sshd -t >/dev/null 2>&1 || { add_reason "sshd -t config validation failed"; return 1; }
  rcctl restart sshd >/dev/null 2>&1 || { add_reason "rcctl restart sshd failed"; return 1; }
  sleep 2
  probe_health "${ip}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check-only) CHECK_ONLY=1 ;;
    --verbose|-v) VERBOSE=1 ;;
    --bind-ip) shift; [ $# -gt 0 ] || die "--bind-ip requires a value"; BIND_IP="$1" ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

need_root
[ -n "${BIND_IP}" ] || BIND_IP="$(extract_bind_ip_from_sshd || true)"
[ -z "${BIND_IP}" ] || validate_ipv4 "${BIND_IP}" || die "invalid bind ip: ${BIND_IP}"

if probe_health "${BIND_IP}"; then
  [ "${VERBOSE}" -eq 1 ] && log_msg "sshd healthy on ${BIND_IP}:22"
  exit 0
fi

if [ "${CHECK_ONLY}" -eq 1 ]; then
  log_msg "sshd unhealthy (check-only): ${HEALTH_REASON}"
  exit 1
fi

log_msg "sshd unhealthy, attempting restart: ${HEALTH_REASON}"
if restart_and_reprobe "${BIND_IP}"; then
  log_msg "sshd recovered and listening on ${BIND_IP}:22"
  exit 0
fi

log_msg "sshd restart failed to restore healthy state: ${HEALTH_REASON}"
exit 1
