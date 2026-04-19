#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
. "${SCRIPT_DIR}/lab-ssh-guard.ksh"

LOCAL_QEMU_CONF="${SCRIPT_DIR}/qemu-lab.conf.local"
[ -f "${LOCAL_QEMU_CONF}" ] && . "${LOCAL_QEMU_CONF}"

REMOTE_REPO="/home/foo/openbsd-mailstack"
REMOTE_INPUT_ROOT="${REMOTE_REPO}/config/local/lab-qemu"

prepare_remote_inputs() {
  ssh -o StrictHostKeyChecking=no -p "${SSH_GUARD_PORT}" "${SSH_GUARD_USER}@${SSH_GUARD_HOST}" <<'EOSSH'
set -eu
cd /home/foo/openbsd-mailstack
mkdir -p config/local/lab-qemu
cp config/examples/lab-qemu/system.conf.example config/local/lab-qemu/system.conf
cp config/examples/lab-qemu/network.conf.example config/local/lab-qemu/network.conf
cp config/examples/lab-qemu/domains.conf.example config/local/lab-qemu/domains.conf
cp config/examples/lab-qemu/secrets.conf.example config/local/lab-qemu/secrets.conf
EOSSH
}

run_remote() {
  _cmd="$1"
  ssh -o StrictHostKeyChecking=no -p "${SSH_GUARD_PORT}" "${SSH_GUARD_USER}@${SSH_GUARD_HOST}" "${_cmd}"
}

main() {
  ssh_guard_wait_ready || { echo "VM did not become SSH ready" >&2; exit 1; }

  rsync -az --delete -e "ssh -o StrictHostKeyChecking=no -p ${SSH_GUARD_PORT}" \
    "${REPO_ROOT}/" "${SSH_GUARD_USER}@${SSH_GUARD_HOST}:${REMOTE_REPO}/"

  prepare_remote_inputs

  run_remote "cd ${REMOTE_REPO} && doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 OPENBSD_MAILSTACK_INPUT_ROOT=${REMOTE_INPUT_ROOT} ksh scripts/bootstrap/install-mailstack-packages.ksh"
  run_remote "cd ${REMOTE_REPO} && doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 OPENBSD_MAILSTACK_INPUT_ROOT=${REMOTE_INPUT_ROOT} ksh scripts/install/run-phase-sequence.ksh --phase-start 0 --phase-end 8"
  run_remote "cd ${REMOTE_REPO} && doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 OPENBSD_MAILSTACK_INPUT_ROOT=${REMOTE_INPUT_ROOT} ksh scripts/install/install-core-runtime-configs.ksh"
  run_remote "cd ${REMOTE_REPO} && doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 OPENBSD_MAILSTACK_INPUT_ROOT=${REMOTE_INPUT_ROOT} ksh scripts/bootstrap/seed-lab-runtime-state.ksh --apply"
  run_remote "cd ${REMOTE_REPO} && doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 OPENBSD_MAILSTACK_INPUT_ROOT=${REMOTE_INPUT_ROOT} ksh scripts/verify/verify-functional-mail-lab.ksh"

  echo "QEMU functional proof run completed"
}

main "$@"
