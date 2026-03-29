# Installation prerequisites and public usage path

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
19. `18-advanced-optional-integrations-and-gap-closures.md`
20. `19-public-repo-readiness-check.md`

## Public discovery map

Use these documents for the corresponding operator goal:

- prerequisites and provider onboarding, `provider-account-and-credential-onboarding.md`
- operator input file placement, `user-input-file-layout.md` and `05-local-provider-secret-file-layout.md`
- QEMU lab path, `06-qemu-lab-and-vm-testing.md` and `10-qemu-first-validation-path.md`
- autonomous installer path, `07-openbsd-autonomous-installer.md`
- install order and phase execution, `09-install-order-and-phase-sequence.md`
- first deployment and post-install checks, `11-first-production-deployment-sequence.md` and `12-post-install-checks.md`
- backup, restore, and DR, `13-dr-site-provisioning.md`, `14-backup-and-restore-drill-sequence.md`, and `15-dr-host-bootstrap.md`
- monitoring and diagnostics, `16-monitoring-diagnostics-and-reporting.md`
- maintenance and regression, `17-maintenance-upgrades-regression-and-rollback.md`
- optional advanced services and SBOM workflows, `18-advanced-optional-integrations-and-gap-closures.md`
- final repo readiness and consistency check, `19-public-repo-readiness-check.md`

## Current state

The public repo now has a coherent path from prerequisites, to staged rendering, to QEMU validation, to first deployment, to backup and DR, to monitoring and maintenance, to optional advanced integrations.

The remaining gaps are narrow and explicit. They are covered in `19-public-repo-readiness-check.md` and `../project-status.md`.

## Security rule

External provider credentials must never be committed to Git. Real values belong in ignored repo-local files, protected host-local files, a secure password manager, or another secure operator-controlled secret store.
