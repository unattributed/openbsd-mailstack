#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMMON_LIB="${REPO_ROOT}/scripts/lib/common.ksh"
[ -f "${COMMON_LIB}" ] || { print -- "ERROR missing shared library: ${COMMON_LIB}" >&2; exit 1; }
. "${COMMON_LIB}"
FAIL=0
CORE_RUNTIME_RENDER_ROOT_REL=".work/runtime/rootfs"

pass() { print -- "PASS: $*"; }
fail() { print -- "FAIL: $*"; FAIL=1; }

tracked_file() {
  _path="$1"
  if command -v git >/dev/null 2>&1 && git -C "${REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "${REPO_ROOT}" ls-files --error-unmatch "${_path}" >/dev/null 2>&1
  else
    [ -e "${REPO_ROOT}/${_path}" ]
  fi
}

for _path in   config/secrets.conf   config/backup.conf   config/dr-site.conf   config/dr-host.conf   config/monitoring.conf   config/maintenance.conf   config/security.conf   config/secrets-runtime.conf; do
  if tracked_file "${_path}"; then
    fail "tracked operator input should not be committed: ${_path}"
  else
    pass "operator input remains untracked: ${_path}"
  fi
done

if command -v git >/dev/null 2>&1 && git -C "${REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "${REPO_ROOT}" grep -n 'PRIVATE KEY-----' -- README.md docs config services >/dev/null 2>&1; then
    fail "tracked publishable files appear to contain private key material"
  else
    pass "no tracked private key markers found in publishable files"
  fi
  if git -C "${REPO_ROOT}" grep -n 'mail.blackbagsecurity.com' -- README.md docs config services >/dev/null 2>&1; then
    fail "tracked publishable files still contain the private deployment hostname"
  else
    pass "no private deployment hostname markers found in publishable files"
  fi
  if git -C "${REPO_ROOT}" check-ignore -q "${CORE_RUNTIME_RENDER_ROOT_REL}"; then
    pass "live core runtime render root is gitignored: ${CORE_RUNTIME_RENDER_ROOT_REL}"
  else
    fail "live core runtime render root should be gitignored: ${CORE_RUNTIME_RENDER_ROOT_REL}"
  fi
  if git -C "${REPO_ROOT}" ls-files .work | grep -q .; then
    fail "tracked files found under .work/"
  else
    pass "no tracked files found under .work/"
  fi
  _expected_mode="$(normalize_mode_octal "$(runtime_secret_file_mode)")"
  while IFS= read -r _rel || [ -n "${_rel}" ]; do
    [ -n "${_rel}" ] || continue
    _path="${REPO_ROOT}/${CORE_RUNTIME_RENDER_ROOT_REL}/${_rel}"
    [ -f "${_path}" ] || continue
    _actual_mode="$(normalize_mode_octal "$(file_mode_octal "${_path}")")"
    if [ -n "${_actual_mode}" ] && [ "${_actual_mode}" = "${_expected_mode}" ]; then
      pass "live runtime secret mode ok (${_actual_mode}): ${CORE_RUNTIME_RENDER_ROOT_REL}/${_rel}"
    else
      fail "live runtime secret mode mismatch, expected ${_expected_mode}, got ${_actual_mode:-unknown}: ${CORE_RUNTIME_RENDER_ROOT_REL}/${_rel}"
    fi
  done <<EOF
$(core_runtime_secret_relative_paths)
EOF
  _sasl_db="${REPO_ROOT}/${CORE_RUNTIME_RENDER_ROOT_REL}/etc/postfix/sasl_passwd.db"
  if [ -f "${_sasl_db}" ]; then
    _actual_mode="$(normalize_mode_octal "$(file_mode_octal "${_sasl_db}")")"
    if [ -n "${_actual_mode}" ] && [ "${_actual_mode}" = "${_expected_mode}" ]; then
      pass "live postfix sasl hash map mode ok (${_actual_mode}): ${CORE_RUNTIME_RENDER_ROOT_REL}/etc/postfix/sasl_passwd.db"
    else
      fail "live postfix sasl hash map mode mismatch, expected ${_expected_mode}, got ${_actual_mode:-unknown}: ${CORE_RUNTIME_RENDER_ROOT_REL}/etc/postfix/sasl_passwd.db"
    fi
  fi
fi

[ "${FAIL}" -eq 0 ]
