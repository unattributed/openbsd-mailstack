# Install Guide

This index is the main public install path for `openbsd-mailstack`.

## Read in this order

### 1. Provider onboarding and local input layout

1. [Provider account and credential onboarding](provider-account-and-credential-onboarding.md)
2. [Vultr account and API setup](02-vultr-account-and-api-setup.md)
3. [Brevo account and relay setup](03-brevo-account-and-relay-setup.md)
4. [VirusTotal API setup](04-virustotal-api-setup.md)
5. [User input file layout](user-input-file-layout.md)
6. [Local provider secret file layout](05-local-provider-secret-file-layout.md)

### 2. Choose your deployment path

1. [Quick start and usage paths](08-quick-start-and-usage-paths.md)
2. [Install order and phase sequence](09-install-order-and-phase-sequence.md)
3. [QEMU-first validation path](10-qemu-first-validation-path.md)
4. [First production deployment sequence](11-first-production-deployment-sequence.md)
5. [Post-install checks](12-post-install-checks.md)

### 3. Optional and later operational layers

1. [DR site provisioning](13-dr-site-provisioning.md)
2. [Backup and restore drill sequence](14-backup-and-restore-drill-sequence.md)
3. [DR host bootstrap](15-dr-host-bootstrap.md)
4. [Monitoring, diagnostics, and reporting](16-monitoring-diagnostics-and-reporting.md)
5. [Maintenance, upgrades, regression, and rollback](17-maintenance-upgrades-regression-and-rollback.md)
6. [Advanced optional integrations and gap closures](18-advanced-optional-integrations-and-gap-closures.md)
7. [Public repo readiness check](19-public-repo-readiness-check.md)
8. [Public-only validation pass](20-public-only-validation-pass.md)
9. [Security hardening and runtime secrets](21-security-hardening-and-runtime-secrets.md)
10. [OpenBSD native ops monitoring site](22-openbsd-native-ops-monitoring-site.md)

## Recommended first-run path

If you are new to the repository:

1. complete provider onboarding and local input setup
2. review the architecture and configuration wiring docs
3. use the QEMU-first path
4. render the live operator trees and inspect `.work/runtime/rootfs/`, `.work/network-exposure/rootfs/`, `.work/identity/`, or `.work/advanced/` as appropriate, using `services/generated/rootfs/` only as the sanitized example reference
5. run the phase sequence through the baseline you want to test
6. build the monitoring layer you want, including the richer static `/_ops/monitor/` site when needed
7. run post-install checks and the public-only validation pass
8. only then move to a real OpenBSD host

## Related documents outside this directory

- [Top-level documentation map](../README.md)
- [Architecture and flow](../architecture/01-project-architecture-and-flow.md)
- [Core runtime and config wiring](../configuration/core-runtime-and-config-wiring.md)
- [Project status](../project-status.md)
- [Phase crosswalk](../phases/phase-crosswalk.md)
