#!/bin/sh
set -eu

DISK=${QEMU_DISK:-/home/foo/VMs/openbsd-mail/disk-lab.qcow2}
OPENBSD_VERSION=${OPENBSD_VERSION:-7.8}
OPENBSD_IMG_TAG=${OPENBSD_IMG_TAG:-$(printf '%s' "${OPENBSD_VERSION}" | tr -d '.')}
ISO=${QEMU_ISO:-/home/foo/VMs/iso/install${OPENBSD_IMG_TAG}.iso}
MEM=${QEMU_MEM:-4096}
SMP=${QEMU_SMP:-2}
DISK_SIZE=${QEMU_DISK_SIZE:-40G}

echo "Creating QEMU disk: ${DISK}"
mkdir -p "$(dirname "${DISK}")"
qemu-img create -f qcow2 "${DISK}" "${DISK_SIZE}"

echo "Launching unattended install helper"
exec expect ./lab-install.expect
