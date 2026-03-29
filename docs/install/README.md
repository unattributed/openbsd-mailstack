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
14. `13-dr-site-provisioning.md`
15. `14-backup-and-restore-drill-sequence.md`
16. `15-dr-host-bootstrap.md`
17. `16-monitoring-diagnostics-and-reporting.md`
18. `17-maintenance-upgrades-regression-and-rollback.md`

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

## What changed in Phase 04

This install set now also includes:

- backup and restore operator input files
- public-safe backup and restore helpers
- a staged restore drill sequence
- DR site provisioning guidance for an internal recovery portal

## What changed in Phase 05

This install set now also includes:

- a shared monitoring operator input file
- public-safe monitoring site rendering
- log summary, health report, and cron-report helpers
- install guidance for nginx, newsyslog, and cron wiring

## What changed in Phase 06

This install set now also includes:

- a shared maintenance operator input file
- public-safe syspatch and package-upgrade wrappers
- regression and rollback guidance for change windows
- optional host-side install helpers for maintenance tooling
- a QEMU rehearsal path for maintenance and upgrade work

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

### Backup and DR path

Use `13-dr-site-provisioning.md`, `14-backup-and-restore-drill-sequence.md`, and `15-dr-host-bootstrap.md` after the core runtime is in place and you are ready to validate resilience.

### Monitoring and diagnostics path

Use `16-monitoring-diagnostics-and-reporting.md` after the runtime and backup layers are in place and you want a daily operator visibility baseline.

### Maintenance and upgrade path

Use `17-maintenance-upgrades-regression-and-rollback.md` after the runtime, backup, and monitoring layers are in place and you want a reproducible maintenance and change-validation workflow.

## Security rule

External provider credentials must never be committed to Git. Real values belong in ignored repo-local files, protected host-local files, a secure password manager, or another secure operator-controlled secret store.



### Later optional advanced layer

- `18-advanced-optional-integrations-and-gap-closures.md`
