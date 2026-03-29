#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"

LIVE_CONF="/etc/doas.conf"
BACKUP_DIR="/var/backups/openbsd-mailstack/doas"
LATEST_PTR="${BACKUP_DIR}/latest-backup"

usage() {
  cat <<'EOF' >&2
usage: doas-policy-transition.ksh --render|--check|--apply|--rollback [backup_path]
EOF
  exit 2
}

need_root() {
  [ "$(id -u)" -eq 0 ] || die "must run as root via doas"
}

ts() { date "+%Y%m%d%H%M%S"; }

normalize_policy() {
  _policy="${1:?policy file required}"
  awk '
    {
      line = $0
      sub(/#.*/, "", line)
      gsub(/[[:space:]]+/, " ", line)
      sub(/^ /, "", line)
      sub(/ $/, "", line)
      if (line != "") print line
    }
  ' "${_policy}" 2>/dev/null
}

load_settings() {
  load_project_config
  : "${DOAS_BREAKGLASS_GROUP:=wheel}"
  : "${DOAS_NOPASS_USER:=${SUDO_USER:-${USER:-operator}}}"
  : "${DOAS_AUTOMATION_OVERLAY_PATH:=/etc/doas-automation-local.conf}"
  : "${DOAS_TRANSITION_ALLOW_CMDS:=true install rcctl pfctl sshd:-t sshd:-T crontab}"
}

render_allowlist_rules() {
  load_settings
  for _token in ${DOAS_TRANSITION_ALLOW_CMDS}; do
    _cmd="${_token%%:*}"
    _rest="${_token#*:}"
    if [ "${_cmd}" = "${_token}" ]; then
      print -- "permit nopass ${DOAS_NOPASS_USER} as root cmd ${_cmd}"
    else
      _args="$(print -- "${_rest}" | tr ',' ' ')"
      print -n -- "permit nopass ${DOAS_NOPASS_USER} as root cmd ${_cmd} args"
      for _arg in ${_args}; do
        print -n -- " ${_arg}"
      done
      print
    fi
  done
}

render_policy() {
  load_settings
  cat <<EOF
# Managed by doas-policy-transition.ksh
permit persist :${DOAS_BREAKGLASS_GROUP}
EOF
  render_allowlist_rules
  if [ -s "${DOAS_AUTOMATION_OVERLAY_PATH}" ]; then
    cat <<EOF

# Approved host-local automation overlay.
# Source: ${DOAS_AUTOMATION_OVERLAY_PATH}
EOF
    cat "${DOAS_AUTOMATION_OVERLAY_PATH}"
  fi
}

validate_policy() {
  _policy="${1:?policy file required}"
  load_settings
  grep -q '^permit persist :' "${_policy}" || {
    echo "error: missing break-glass persist rule" >&2
    return 1
  }
  grep -q "^permit nopass ${DOAS_NOPASS_USER} as root cmd install$" "${_policy}" || {
    echo "error: missing install allowlist rule" >&2
    return 1
  }
  grep -q 'keepenv' "${_policy}" && {
    echo "error: command-scoped policy should not contain keepenv" >&2
    return 1
  }
  if command -v doas >/dev/null 2>&1; then
    doas -C "${_policy}" true >/dev/null 2>&1 || {
      echo "error: doas -C rejected ${_policy}" >&2
      return 1
    }
  fi
}

check_mode() {
  need_root
  _tmp="/tmp/openbsd-mailstack-doas-transition.$$"
  _live_norm="${_tmp}.live"
  _expect_norm="${_tmp}.expect"
  trap 'rm -f "${_tmp}" "${_live_norm}" "${_expect_norm}"' EXIT INT TERM
  render_policy > "${_tmp}"
  validate_policy "${_tmp}"
  [ -r "${LIVE_CONF}" ] || die "live policy not readable: ${LIVE_CONF}"
  validate_policy "${LIVE_CONF}"
  normalize_policy "${LIVE_CONF}" > "${_live_norm}"
  normalize_policy "${_tmp}" > "${_expect_norm}"
  if cmp -s "${_live_norm}" "${_expect_norm}"; then
    print -- "ok: live doas policy matches rendered command-scoped baseline"
    return 0
  fi
  print -- "error: live ${LIVE_CONF} drifts from rendered command-scoped baseline" >&2
  diff -u "${_expect_norm}" "${_live_norm}" >&2 || true
  return 1
}

apply_mode() {
  need_root
  _tmp="/tmp/openbsd-mailstack-doas-transition.$$"
  trap 'rm -f "${_tmp}"' EXIT INT TERM
  render_policy > "${_tmp}"
  validate_policy "${_tmp}"
  install -d -o root -g wheel -m 0700 "${BACKUP_DIR}"
  if [ -f "${LIVE_CONF}" ]; then
    _backup="${BACKUP_DIR}/doas.conf.pre-$(ts)"
    install -o root -g wheel -m 0600 "${LIVE_CONF}" "${_backup}"
    printf '%s
' "${_backup}" > "${LATEST_PTR}"
    chmod 0600 "${LATEST_PTR}" || true
  fi
  install -o root -g wheel -m 0600 "${_tmp}" "${LIVE_CONF}"
  doas -C "${LIVE_CONF}" true >/dev/null 2>&1 || die "installed policy failed doas -C validation"
  print -- "ok: installed ${LIVE_CONF}"
}

rollback_mode() {
  need_root
  _backup="${1:-}"
  if [ -z "${_backup}" ] && [ -f "${LATEST_PTR}" ]; then
    _backup="$(cat "${LATEST_PTR}")"
  fi
  [ -n "${_backup}" ] || die "no rollback backup specified and latest-backup pointer missing"
  [ -f "${_backup}" ] || die "backup file not found: ${_backup}"
  install -o root -g wheel -m 0600 "${_backup}" "${LIVE_CONF}"
  doas -C "${LIVE_CONF}" true >/dev/null 2>&1 || die "restored policy failed doas -C validation"
  print -- "ok: restored ${LIVE_CONF} from ${_backup}"
}

case "${1:-}" in
  --render) render_policy ;;
  --check) check_mode ;;
  --apply) apply_mode ;;
  --rollback) rollback_mode "${2:-}" ;;
  *) usage ;;
esac
