#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/lab-ssh-guard.ksh"

CMD=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --cmd) CMD="$2"; shift 2 ;;
    --port) SSH_GUARD_PORT="$2"; shift 2 ;;
    --user) SSH_GUARD_USER="$2"; shift 2 ;;
    --host) SSH_GUARD_HOST="$2"; shift 2 ;;
    --help|-h)
      echo "usage: lab-vm-ssh.ksh [--cmd 'uname -a'] [--host HOST] [--port PORT] [--user USER]"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -n "$CMD" ]; then
  exec ssh -o StrictHostKeyChecking=no -p "${SSH_GUARD_PORT}" "${SSH_GUARD_USER}@${SSH_GUARD_HOST}" "$CMD"
fi

exec ssh -o StrictHostKeyChecking=no -p "${SSH_GUARD_PORT}" "${SSH_GUARD_USER}@${SSH_GUARD_HOST}"
