#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

: "${OPENBSD_VERSION:=7.8}"
: "${QEMU_ISO:=/home/foo/VMs/iso/install78.iso}"

echo "Building OpenBSD ${OPENBSD_VERSION} lab VM"
echo "Expected install media: ${QEMU_ISO}"

if [ ! -f "${QEMU_ISO}" ]; then
  echo "Missing ISO: ${QEMU_ISO}" >&2
  echo "Run: ksh ${SCRIPT_DIR}/fetch-openbsd-amd64-media.ksh --release ${OPENBSD_VERSION}" >&2
  exit 1
fi

(
  cd "${SCRIPT_DIR}"
  ./lab-install.sh
)

echo "Base install completed"
echo "Next recommended steps:"
echo "  expect ${SCRIPT_DIR}/lab-bootstrap.expect"
echo "  expect ${SCRIPT_DIR}/lab-ssh-bootstrap.expect"
