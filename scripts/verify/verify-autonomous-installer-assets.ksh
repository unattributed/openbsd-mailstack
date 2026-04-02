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
BUILD_ROOT="${OPENBSD_MAILSTACK_AUTOINSTALL_BUILD_ROOT:-${PROJECT_ROOT}/maint/openbsd-autonomous-installer/build}"

pass() { print -- "[$(timestamp)] PASS  $*"; PASS=$((PASS + 1)); }
fail() { print -- "[$(timestamp)] FAIL  $*"; FAIL=$((FAIL + 1)); }

check_file() {
  _path="$1"
  _label="$2"
  if [ -f "${_path}" ]; then
    pass "${_label}: ${_path#${PROJECT_ROOT}/}"
  else
    fail "${_label} missing: ${_path#${PROJECT_ROOT}/}"
  fi
}

check_var_in_example() {
  _var="$1"
  _file="$2"
  if grep -Eq '^'"${_var}"'=' "${_file}"; then
    pass "installer example defines ${_var}"
  else
    fail "installer example missing ${_var}"
  fi
}

check_no_placeholders() {
  _file="$1"
  _label="$2"
  if grep -Eq '__[A-Z0-9_][A-Z0-9_]*__' "${_file}"; then
    fail "${_label} still contains unresolved placeholders: ${_file}"
  else
    pass "${_label} free of unresolved placeholders: ${_file}"
  fi
}

check_build_outputs() {
  [ -d "${BUILD_ROOT}" ] || {
    pass "no rendered autonomous installer build root present, repo asset checks only"
    return 0
  }
  _found=0
  for _dir in "${BUILD_ROOT}"/*; do
    [ -d "${_dir}" ] || continue
    _found=1
    check_file "${_dir}/install.conf.78.lab" "installer build output"
    check_file "${_dir}/install.conf.78.real" "installer build output"
    check_file "${_dir}/disklabel-root-swap.template" "installer build output"
    check_file "${_dir}/site78.tgz" "installer build output"
    check_file "${_dir}/ACCOUNT-READINESS.md" "installer build output"
    [ -f "${_dir}/install.conf.78.lab" ] && check_no_placeholders "${_dir}/install.conf.78.lab" "installer lab config"
    [ -f "${_dir}/install.conf.78.real" ] && check_no_placeholders "${_dir}/install.conf.78.real" "installer real config"
    [ -f "${_dir}/ACCOUNT-READINESS.md" ] && check_no_placeholders "${_dir}/ACCOUNT-READINESS.md" "installer readiness summary"
  done
  [ "${_found}" -eq 1 ] || pass "autonomous installer build root exists but contains no rendered profiles yet"
}

main() {
  _dir="${PROJECT_ROOT}/maint/openbsd-autonomous-installer"
  _example="${_dir}/installer-profile.example.env"

  for _file in     "${_dir}/README.md"     "${_dir}/installer-profile.example.env"     "${_dir}/guided-profile-builder.ksh"     "${_dir}/render-installer-pack.ksh"     "${_dir}/install.conf.78.lab.template"     "${_dir}/install.conf.78.real.template"     "${_dir}/disklabel-root-swap.template"     "${_dir}/serve-autoinstall.sh"     "${_dir}/site78_root/install.site.template"     "${_dir}/site78_root/root/phase00-firstboot.sh.template"
  do
    check_file "${_file}" "autonomous installer asset present"
  done

  for _var in PROFILE_NAME OPENBSD_VERSION OPENBSD_ARCH SYSTEM_HOSTNAME DNS_DOMAIN TIMEZONE OPERATOR_USER OPERATOR_HOME ROOT_PASSWORD_BCRYPT PARROT_PUBKEY LAN_IF_DEFAULT LAN_NET_DEFAULT HOST_IP_DEFAULT HOST_IP_CIDR_REAL HOST_GATEWAY_DEFAULT NAMESERVER_DEFAULT AUTOINSTALL_HTTP_HOST AUTOINSTALL_HTTP_PORT MAILSTACK_REPO_CLONE_URL; do
    check_var_in_example "${_var}" "${_example}"
  done

  if grep -Fq 'installer-profile.local.env' "${PROJECT_ROOT}/docs/install/07-openbsd-autonomous-installer.md" && grep -Eq 'local and untracked|intentionally local and untracked' "${PROJECT_ROOT}/docs/install/07-openbsd-autonomous-installer.md"; then
    pass "autonomous installer doc correctly describes local untracked profile"
  else
    fail "autonomous installer doc does not clearly describe local untracked profile"
  fi

  check_build_outputs

  print
  print -- "Autonomous installer asset validation summary"
  print -- "  PASS count : ${PASS}"
  print -- "  FAIL count : ${FAIL}"
  print
  [ "${FAIL}" -eq 0 ]
}

main "$@"
