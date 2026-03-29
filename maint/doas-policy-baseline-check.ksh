#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"

usage() {
  cat <<'EOF' >&2
usage: doas-policy-baseline-check.ksh --render|--check [policy_path]
EOF
  exit 2
}

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
}

render_policy() {
  load_settings
  cat <<EOF
# Managed by doas-policy-baseline-check.ksh
permit persist :${DOAS_BREAKGLASS_GROUP}
permit keepenv nopass ${DOAS_NOPASS_USER} as root
EOF
}

validate_policy() {
  _policy="${1:?policy file required}"
  load_settings
  grep -q "^permit persist :${DOAS_BREAKGLASS_GROUP}$" "${_policy}" || {
    echo "error: missing break-glass persist rule" >&2
    return 1
  }
  grep -q "^permit keepenv nopass ${DOAS_NOPASS_USER} as root$" "${_policy}" || {
    echo "error: missing project baseline user rule" >&2
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
  _policy="${1:-/etc/doas.conf}"
  _tmp="/tmp/openbsd-mailstack-doas-baseline.$$"
  _live_norm="${_tmp}.live"
  _expect_norm="${_tmp}.expect"
  trap 'rm -f "${_tmp}" "${_live_norm}" "${_expect_norm}"' EXIT INT TERM
  [ -r "${_policy}" ] || die "policy not readable: ${_policy}"
  render_policy > "${_tmp}"
  validate_policy "${_tmp}"
  validate_policy "${_policy}"
  normalize_policy "${_policy}" > "${_live_norm}"
  normalize_policy "${_tmp}" > "${_expect_norm}"
  if cmp -s "${_live_norm}" "${_expect_norm}"; then
    print -- "ok: live doas policy matches rendered baseline"
    return 0
  fi
  print -- "error: live ${_policy} drifts from rendered baseline" >&2
  diff -u "${_expect_norm}" "${_live_norm}" >&2 || true
  return 1
}

case "${1:-}" in
  --render) render_policy ;;
  --check) check_mode "${2:-/etc/doas.conf}" ;;
  *) usage ;;
esac
