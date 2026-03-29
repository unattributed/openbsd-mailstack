#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"

LIVE_CONF="/etc/ssh/sshd_config"
BACKUP_DIR="/var/backups/openbsd-mailstack/sshd"
LATEST_PTR="${BACKUP_DIR}/latest-backup"

usage() {
  cat <<'EOF' >&2
usage: ssh-hardening-window.ksh --plan|--apply|--verify|--rollback [backup_path]
EOF
  exit 2
}

need_root() {
  [ "$(id -u)" -eq 0 ] || die "must run as root via doas"
}

ts() { date "+%Y%m%d%H%M%S"; }

load_settings() {
  load_project_config
  : "${SSH_PERMIT_ROOT_LOGIN:=no}"
  : "${SSH_PASSWORD_AUTHENTICATION:=no}"
  : "${SSH_KBDINTERACTIVE_AUTHENTICATION:=no}"
  : "${SSH_PUBKEY_AUTHENTICATION:=yes}"
  : "${SSH_MAX_AUTH_TRIES:=4}"
  : "${SSH_MAX_SESSIONS:=8}"
  : "${SSH_CLIENT_ALIVE_INTERVAL:=300}"
  : "${SSH_CLIENT_ALIVE_COUNT_MAX:=2}"
  : "${SSH_LOGIN_GRACE_TIME:=30}"
}

target_settings() {
  load_settings
  cat <<EOF
PermitRootLogin ${SSH_PERMIT_ROOT_LOGIN}
PasswordAuthentication ${SSH_PASSWORD_AUTHENTICATION}
KbdInteractiveAuthentication ${SSH_KBDINTERACTIVE_AUTHENTICATION}
PubkeyAuthentication ${SSH_PUBKEY_AUTHENTICATION}
MaxAuthTries ${SSH_MAX_AUTH_TRIES}
MaxSessions ${SSH_MAX_SESSIONS}
ClientAliveInterval ${SSH_CLIENT_ALIVE_INTERVAL}
ClientAliveCountMax ${SSH_CLIENT_ALIVE_COUNT_MAX}
LoginGraceTime ${SSH_LOGIN_GRACE_TIME}
EOF
}

show_effective() {
  sshd -T 2>/dev/null | egrep '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|maxauthtries|clientaliveinterval|clientalivecountmax|logingracetime|maxsessions|pubkeyauthentication)'
}

apply_targets() {
  _file="${1:?file required}"
  _targets_file="${_file}.targets.$$"
  _updated_file="${_file}.tmp.$$"
  target_settings > "${_targets_file}"
  awk -v targets="${_targets_file}" '
    BEGIN {
      while ((getline line < targets) > 0) {
        if (line == "") continue
        split(line, a, /[[:space:]]+/)
        key = tolower(a[1])
        want[key] = line
        order[++n] = key
      }
      close(targets)
    }
    {
      line = $0
      stripped = line
      sub(/^[[:space:]]*#?[[:space:]]*/, "", stripped)
      token = stripped
      sub(/[[:space:]].*$/, "", token)
      key = tolower(token)
      if (key in want) {
        if (!(key in done)) {
          print want[key]
          done[key] = 1
        }
        next
      }
      print $0
    }
    END {
      for (i = 1; i <= n; i++) {
        key = order[i]
        if (!(key in done)) print want[key]
      }
    }
  ' "${_file}" > "${_updated_file}"
  mv "${_updated_file}" "${_file}"
  rm -f "${_targets_file}"
}

plan_mode() {
  print -- "Current effective sshd settings:"
  show_effective || true
  print
  print -- "Planned targets:"
  target_settings
}

verify_mode() {
  need_root
  _effective_tmp="/tmp/openbsd-mailstack-sshd-effective.$$"
  trap 'rm -f "${_effective_tmp}"' EXIT INT TERM
  sshd -T > "${_effective_tmp}"
  _fail=0
  while IFS=' ' read -r _key _value; do
    [ -n "${_key}" ] || continue
    _actual="$(awk -v want="$(printf '%s' "${_key}" | tr '[:upper:]' '[:lower:]')" '$1 == want { print $2; exit }' "${_effective_tmp}")"
    if [ "${_actual}" = "${_value}" ]; then
      print -- "ok: ${_key}=${_value}"
    else
      print -- "error: ${_key} expected ${_value} but found ${_actual:-missing}" >&2
      _fail=$((_fail + 1))
    fi
  done <<EOF
$(target_settings)
EOF
  rcctl check sshd >/dev/null 2>&1 || die "rcctl check sshd failed"
  if [ "${_fail}" -ne 0 ]; then
    die "ssh hardening target mismatch count=${_fail}"
  fi
  print -- "ok: ssh hardening targets verified"
}

apply_mode() {
  need_root
  [ -f "${LIVE_CONF}" ] || die "missing ${LIVE_CONF}"
  install -d -o root -g wheel -m 0700 "${BACKUP_DIR}"
  _backup="${BACKUP_DIR}/sshd_config.pre-$(ts)"
  _tmp="/tmp/openbsd-mailstack-sshd.$$"
  trap 'rm -f "${_tmp}"' EXIT INT TERM
  install -o root -g wheel -m 0600 "${LIVE_CONF}" "${_backup}"
  printf '%s
' "${_backup}" > "${LATEST_PTR}"
  chmod 0600 "${LATEST_PTR}" || true
  install -o root -g wheel -m 0600 "${LIVE_CONF}" "${_tmp}"
  apply_targets "${_tmp}"
  sshd -t -f "${_tmp}" || die "sshd -t validation failed"
  install -o root -g wheel -m 0600 "${_tmp}" "${LIVE_CONF}"
  rcctl restart sshd
  verify_mode
}

rollback_mode() {
  need_root
  _backup="${1:-}"
  if [ -z "${_backup}" ] && [ -f "${LATEST_PTR}" ]; then
    _backup="$(cat "${LATEST_PTR}")"
  fi
  [ -n "${_backup}" ] || die "no rollback backup specified and no latest-backup pointer"
  [ -f "${_backup}" ] || die "backup file not found: ${_backup}"
  install -o root -g wheel -m 0600 "${_backup}" "${LIVE_CONF}"
  sshd -t -f "${LIVE_CONF}" || die "restored config failed sshd -t"
  rcctl restart sshd
  verify_mode
}

case "${1:-}" in
  --plan) plan_mode ;;
  --apply) apply_mode ;;
  --verify) verify_mode ;;
  --rollback) rollback_mode "${2:-}" ;;
  *) usage ;;
esac
