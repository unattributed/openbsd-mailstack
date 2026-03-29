#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REMOTE="${1:-origin}"
BRANCH="${2:-main}"

command -v git >/dev/null 2>&1 || { print -- "git not found" >&2; exit 1; }
git -C "${REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { print -- "not a git repo: ${REPO_ROOT}" >&2; exit 1; }
git -C "${REPO_ROOT}" diff --quiet --ignore-submodules HEAD -- || { print -- "working tree is not clean" >&2; exit 1; }

git -C "${REPO_ROOT}" fetch "${REMOTE}"
git -C "${REPO_ROOT}" merge --ff-only "${REMOTE}/${BRANCH}"
print -- "PASS: synced ${REMOTE}/${BRANCH}"
