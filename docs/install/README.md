# Installation Prerequisites

## Purpose

This directory contains external prerequisites and install-side preparation documents that should be completed before the phase-driven build is started.

## Recommended order

1. `provider-account-and-credential-onboarding.md`
2. `02-vultr-account-and-api-setup.md`
3. `03-brevo-account-and-relay-setup.md`
4. `04-virustotal-api-setup.md`
5. `user-input-file-layout.md`
6. `05-local-provider-secret-file-layout.md`
7. `06-qemu-lab-and-vm-testing.md`
8. `07-openbsd-autonomous-installer.md`
9. `08-quick-start-and-usage-paths.md`

## What changed in Phase 01

This install set now distinguishes between:

- provider account creation
- local file placement for operator values
- tracked examples
- ignored repo-local files
- protected host-local files

Use the new onboarding and file-layout docs before running early phases.

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

External provider credentials must never be committed to Git. Real values belong in ignored repo-local files, protected host-local files, a secure password manager, or another secure operator-controlled secret store.
