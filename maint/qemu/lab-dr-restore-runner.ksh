#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
. "${SCRIPT_DIR}/lab-ssh-guard.ksh"

ARCHIVE=""
SHA_FILE=""
REMOTE_REPO="/home/foo/openbsd-mailstack"
REMOTE_STAGE_BASE="/home/foo/dr-restore"

usage() {
  cat <<'EOF'
usage: lab-dr-restore-runner.ksh --archive FILE [--sha256 FILE]
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --archive) ARCHIVE="$2"; shift 2 ;;
    --sha256) SHA_FILE="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "${ARCHIVE}" ] || { usage >&2; exit 2; }
[ -f "${ARCHIVE}" ] || { echo "archive not found: ${ARCHIVE}" >&2; exit 1; }
[ -z "${SHA_FILE}" ] || [ -f "${SHA_FILE}" ] || { echo "sha256 file not found: ${SHA_FILE}" >&2; exit 1; }

ssh_guard_wait_ready || { echo "VM did not become SSH ready" >&2; exit 1; }
ssh_guard_open_master

rsync -az --delete -e "ssh -o StrictHostKeyChecking=no -p ${SSH_GUARD_PORT}" "${REPO_ROOT}/" "${SSH_GUARD_USER}@${SSH_GUARD_HOST}:${REMOTE_REPO}/"
ssh -o StrictHostKeyChecking=no -p "${SSH_GUARD_PORT}" "${SSH_GUARD_USER}@${SSH_GUARD_HOST}" "mkdir -p '${REMOTE_STAGE_BASE}/input' '${REMOTE_STAGE_BASE}/work'"
scp -P "${SSH_GUARD_PORT}" -o StrictHostKeyChecking=no "${ARCHIVE}" "${SSH_GUARD_USER}@${SSH_GUARD_HOST}:${REMOTE_STAGE_BASE}/input/"
if [ -n "${SHA_FILE}" ]; then
  scp -P "${SSH_GUARD_PORT}" -o StrictHostKeyChecking=no "${SHA_FILE}" "${SSH_GUARD_USER}@${SSH_GUARD_HOST}:${REMOTE_STAGE_BASE}/input/"
fi

REMOTE_ARCHIVE="${REMOTE_STAGE_BASE}/input/$(basename "${ARCHIVE}")"
REMOTE_SHA=""
if [ -n "${SHA_FILE}" ]; then
  REMOTE_SHA="${REMOTE_STAGE_BASE}/input/$(basename "${SHA_FILE}")"
fi

if [ -n "${REMOTE_SHA}" ]; then
  ssh -o StrictHostKeyChecking=no -p "${SSH_GUARD_PORT}" "${SSH_GUARD_USER}@${SSH_GUARD_HOST}"     "cd '${REMOTE_REPO}' && ksh scripts/ops/run-restore-drill.ksh --archive '${REMOTE_ARCHIVE}' --sha256 '${REMOTE_SHA}' --stage-dir '${REMOTE_STAGE_BASE}/work'"
else
  ssh -o StrictHostKeyChecking=no -p "${SSH_GUARD_PORT}" "${SSH_GUARD_USER}@${SSH_GUARD_HOST}"     "cd '${REMOTE_REPO}' && ksh scripts/ops/run-restore-drill.ksh --archive '${REMOTE_ARCHIVE}' --stage-dir '${REMOTE_STAGE_BASE}/work'"
fi

echo "QEMU restore drill completed"
