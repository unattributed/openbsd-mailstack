#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
. "${SCRIPT_DIR}/lab-ssh-guard.ksh"

REMOTE_REPO="${REMOTE_REPO:-/home/foo/openbsd-mailstack}"
REMOTE_USER="${SSH_GUARD_USER}"
REMOTE_HOST="${SSH_GUARD_HOST}"
REMOTE_PORT="${SSH_GUARD_PORT}"
MODE="report"

usage() {
  cat <<'EOF2'
usage: lab-openbsd78-upgrade.ksh [--report|--apply]

This script expects a reachable lab VM and reuses the SSH guard settings from
maint/qemu/lab-ssh-guard.ksh. It syncs the public repo into the lab guest and
runs the maintenance workflow there.
EOF2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --report) MODE="report"; shift ;;
    --apply) MODE="apply"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) print -- "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

ssh_guard_wait_ready || { print -- "VM did not become SSH ready" >&2; exit 1; }
rsync -az --delete -e "ssh -o StrictHostKeyChecking=no -p ${REMOTE_PORT}" "${REPO_ROOT}/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_REPO}/"
ssh -o StrictHostKeyChecking=no -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" \
  "cd '${REMOTE_REPO}' && doas ksh ./scripts/ops/maintenance-run.ksh --${MODE}"
