#!/bin/ksh
if [ "${LAB_SSH_GUARD_VERSION:-}" = "public-r1" ]; then
  return 0 2>/dev/null || true
fi
LAB_SSH_GUARD_VERSION="public-r1"

: "${SSH_GUARD_USER:=foo}"
: "${SSH_GUARD_HOST:=127.0.0.1}"
: "${SSH_GUARD_PORT:=2222}"
: "${SSH_GUARD_CONTROL_PATH:=/tmp/openbsd-mailstack-qemu.sock}"
: "${SSH_GUARD_CONNECT_TIMEOUT:=10}"

ssh_guard_wait_ready() {
  i=0
  while [ "$i" -lt 60 ]; do
    if ssh -o BatchMode=yes -o ConnectTimeout="${SSH_GUARD_CONNECT_TIMEOUT}" -o StrictHostKeyChecking=no -p "${SSH_GUARD_PORT}" "${SSH_GUARD_USER}@${SSH_GUARD_HOST}" true >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 5
  done
  return 1
}

ssh_guard_open_master() {
  ssh -MNf     -o ControlMaster=yes     -o ControlPersist=600     -o StrictHostKeyChecking=no     -o ControlPath="${SSH_GUARD_CONTROL_PATH}"     -p "${SSH_GUARD_PORT}"     "${SSH_GUARD_USER}@${SSH_GUARD_HOST}"
}

ssh_guard_run() {
  ssh     -o ControlPath="${SSH_GUARD_CONTROL_PATH}"     -o ControlMaster=no     -p "${SSH_GUARD_PORT}"     "${SSH_GUARD_USER}@${SSH_GUARD_HOST}" "$@"
}

ssh_guard_pipe_to_remote() {
  ssh     -o ControlPath="${SSH_GUARD_CONTROL_PATH}"     -o ControlMaster=no     -p "${SSH_GUARD_PORT}"     "${SSH_GUARD_USER}@${SSH_GUARD_HOST}" "$@"
}

ssh_guard_close_master() {
  ssh     -O exit     -o ControlPath="${SSH_GUARD_CONTROL_PATH}"     -p "${SSH_GUARD_PORT}"     "${SSH_GUARD_USER}@${SSH_GUARD_HOST}" >/dev/null 2>&1 || true
}
