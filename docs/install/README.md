# Installation Prerequisites

## Purpose

This directory contains external prerequisites and install-side preparation documents that should be completed before the phase-driven build is started.

## Recommended order

1. `02-vultr-account-and-api-setup.md`
2. `03-brevo-account-and-relay-setup.md`
3. `04-virustotal-api-setup.md`
4. `05-local-provider-secret-file-layout.md`
5. `06-qemu-lab-and-vm-testing.md`
6. `07-openbsd-autonomous-installer.md`

## Optional operator paths

### QEMU lab path

Use `06-qemu-lab-and-vm-testing.md` when you want to prototype or validate the project in a disposable VM.

### Autonomous installer path

Use `07-openbsd-autonomous-installer.md` when you want to build a custom OpenBSD autoinstall pack that can be adapted to your own:

- LAN interface
- LAN network
- host IP
- operator username
- operator home path
- public SSH key

## Security rule

External provider credentials must never be committed to Git. Real values belong in a secure password manager, protected local secret files, or another secure operator-controlled secret store.
