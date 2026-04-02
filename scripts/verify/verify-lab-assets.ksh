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
    pass "qemu example defines ${_var}"
  else
    fail "qemu example missing ${_var}"
  fi
}

main() {
  _qemu_dir="${PROJECT_ROOT}/maint/qemu"
  _example="${_qemu_dir}/qemu-lab.conf.example"

  for _file in     "${_qemu_dir}/README.md"     "${_qemu_dir}/qemu-lab.conf.example"     "${_qemu_dir}/fetch-openbsd-amd64-media.ksh"     "${_qemu_dir}/lab-install.sh"     "${_qemu_dir}/lab-install.expect"     "${_qemu_dir}/lab-bootstrap.expect"     "${_qemu_dir}/lab-ssh-bootstrap.expect"     "${_qemu_dir}/lab-openbsd78-build.ksh"     "${_qemu_dir}/lab-phase-runner.ksh"     "${_qemu_dir}/lab-ssh-guard.ksh"     "${_qemu_dir}/lab-vm-ssh.ksh"     "${_qemu_dir}/vm-phase-report-runner.ksh"     "${_qemu_dir}/lab-dr-restore-runner.ksh"     "${_qemu_dir}/lab-openbsd78-upgrade.ksh"
  do
    check_file "${_file}" "qemu asset present"
  done

  for _var in OPENBSD_VERSION OPENBSD_ARCH OPENBSD_MIRROR QEMU_ISO_DIR QEMU_VM_DIR QEMU_DISK QEMU_ISO QEMU_MEM QEMU_SMP LAB_SSH_HOST LAB_SSH_PORT LAB_VM_NAME HOST_REPO_PATH; do
    check_var_in_example "${_var}" "${_example}"
  done

  if grep -Fq 'qemu-lab.conf.local' "${PROJECT_ROOT}/docs/install/06-qemu-lab-and-vm-testing.md" && grep -Eq 'local and untracked|intentionally not tracked' "${PROJECT_ROOT}/docs/install/06-qemu-lab-and-vm-testing.md"; then
    pass "qemu install doc correctly describes local lab config"
  else
    fail "qemu install doc does not clearly describe local untracked lab config"
  fi

  print
  print -- "QEMU lab asset validation summary"
  print -- "  PASS count : ${PASS}"
  print -- "  FAIL count : ${FAIL}"
  print
  [ "${FAIL}" -eq 0 ]
}

main "$@"
