# Installation Prerequisites and Public Usage Path

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
10. `09-install-order-and-phase-sequence.md`
11. `10-qemu-first-validation-path.md`
12. `11-first-production-deployment-sequence.md`
13. `12-post-install-checks.md`

## What changed in Phase 01

This install set now distinguishes between:

- provider account creation
- local file placement for operator values
- tracked examples
- ignored repo-local files
- protected host-local files

Use the new onboarding and file-layout docs before running early phases.

## What changed in Phase 03

This install set now also includes:

- a coherent install order for the first public baseline
- a QEMU-first validation path that uses only public repo assets
- a first production deployment sequence
- a post-install validation path based on reusable scripts

## Optional operator paths

### QEMU lab path

Use `06-qemu-lab-and-vm-testing.md` and `10-qemu-first-validation-path.md` when you want to prototype or validate the project in a disposable VM.

### Autonomous installer path

Use `07-openbsd-autonomous-installer.md` when you want to build a custom OpenBSD autoinstall pack that can be adapted to your own:

- LAN interface
- LAN network
- host IP
- operator username
- operator home path
- public SSH key

### Direct host path

Use `09-install-order-and-phase-sequence.md`, `11-first-production-deployment-sequence.md`, and `12-post-install-checks.md` when you want to move from staged config rendering to a real OpenBSD host.

## Security rule

External provider credentials must never be committed to Git. Real values belong in ignored repo-local files, protected host-local files, a secure password manager, or another secure operator-controlled secret store.
