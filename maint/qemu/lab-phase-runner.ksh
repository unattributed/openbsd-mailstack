#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
. "${SCRIPT_DIR}/lab-ssh-guard.ksh"

PHASE_START=""
PHASE_END=""

usage() {
  cat <<'USAGE'
usage: lab-phase-runner.ksh --phase-start NN --phase-end NN
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --phase-start) PHASE_START="$2"; shift 2 ;;
    --phase-end) PHASE_END="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[ -n "${PHASE_START}" ] || { usage >&2; exit 1; }
[ -n "${PHASE_END}" ] || { usage >&2; exit 1; }

echo "Waiting for lab SSH readiness"
ssh_guard_wait_ready || { echo "VM did not become SSH ready" >&2; exit 1; }

echo "Syncing repo into VM"
rsync -az --delete   -e "ssh -o StrictHostKeyChecking=no -p ${SSH_GUARD_PORT}"   "${REPO_ROOT}/"   "${SSH_GUARD_USER}@${SSH_GUARD_HOST}:/home/foo/openbsd-mailstack/"

p="$PHASE_START"
while [ "$p" -le "$PHASE_END" ]; do
  phase="$(printf '%02d' "$p")"
  echo "Running phase ${phase}"
  ssh -o StrictHostKeyChecking=no -p "${SSH_GUARD_PORT}"     "${SSH_GUARD_USER}@${SSH_GUARD_HOST}"     "cd /home/foo/openbsd-mailstack && ksh maint/qemu/vm-phase-report-runner.ksh --phase ${phase}"
  p=$((p + 1))
done

echo "Phase runner completed"
