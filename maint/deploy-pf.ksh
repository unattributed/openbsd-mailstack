#!/bin/ksh
set -e
set -o pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"

"${PROJECT_ROOT}/scripts/install/install-network-exposure-assets.ksh" --apply
if command -v pfctl >/dev/null 2>&1; then
  if [ "$(id -u)" -eq 0 ]; then
    pfctl -nf /etc/pf.conf
    pfctl -f /etc/pf.conf
  else
    doas -n pfctl -nf /etc/pf.conf
    doas -n pfctl -f /etc/pf.conf
  fi
fi
