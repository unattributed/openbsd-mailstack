# Documentation Map

This file is the documentation index for `openbsd-mailstack`.

## Read in this order

1. [Project status](project-status.md)
2. [Public and private boundary](public-private-boundary.md)
3. [Phase crosswalk](phases/phase-crosswalk.md)
4. [Install guide](install/README.md)
5. [Architecture and flow](architecture/01-project-architecture-and-flow.md)
6. [Operator workflow](operations/01-operator-workflow.md)
7. [Public repo readiness check](install/19-public-repo-readiness-check.md)
8. [Public-only validation pass](install/20-public-only-validation-pass.md)

## Core architecture and build flow

- [Project architecture and flow](architecture/01-project-architecture-and-flow.md)
- [Core runtime and config wiring](configuration/core-runtime-and-config-wiring.md)

## Install and validation

- [Install guide](install/README.md)
- [Quick start and usage paths](install/08-quick-start-and-usage-paths.md)
- [Install order and phase sequence](install/09-install-order-and-phase-sequence.md)
- [QEMU-first validation path](install/10-qemu-first-validation-path.md)
- [First production deployment sequence](install/11-first-production-deployment-sequence.md)
- [Post-install checks](install/12-post-install-checks.md)
- [Public repo readiness check](install/19-public-repo-readiness-check.md)
- [Public-only validation pass](install/20-public-only-validation-pass.md)
- [Security hardening and runtime secrets](install/21-security-hardening-and-runtime-secrets.md)
- [OpenBSD native ops monitoring site](install/22-openbsd-native-ops-monitoring-site.md)

## Provider onboarding and operator inputs

- [Provider account and credential onboarding](install/provider-account-and-credential-onboarding.md)
- [User input file layout](install/user-input-file-layout.md)
- [Local provider secret file layout](install/05-local-provider-secret-file-layout.md)
- [Vultr account and API setup](install/02-vultr-account-and-api-setup.md)
- [Brevo account and relay setup](install/03-brevo-account-and-relay-setup.md)
- [VirusTotal API setup](install/04-virustotal-api-setup.md)
- [Configuration examples](../config/examples/README.md)

## Monitoring and operations visibility

- [Monitoring baseline](15-monitoring-and-reporting-baseline.md)
- [Monitoring, diagnostics, and reporting](install/16-monitoring-diagnostics-and-reporting.md)
- [OpenBSD native ops monitoring site](install/22-openbsd-native-ops-monitoring-site.md)
- [Monitoring, diagnostics, and reporting](operations/05-monitoring-diagnostics-and-reporting.md)

## Operator workflows

- [Operator workflow](operations/01-operator-workflow.md)
- [Daily operator workflow](operations/02-daily-operator-workflow.md)
- [Weekly operator workflow](operations/03-weekly-operator-workflow.md)
- [Backup and DR operator workflow](operations/04-backup-and-dr-operator-workflow.md)
- [Monitoring, diagnostics, and reporting](operations/05-monitoring-diagnostics-and-reporting.md)
- [Maintenance, upgrades, and regression](operations/06-maintenance-upgrades-and-regression.md)
- [Advanced ops and optional integrations](operations/07-advanced-ops-and-optional-integrations.md)
- [Security hardening and secrets operations](operations/08-security-hardening-and-secrets-ops.md)

## Phase documents

Start with the [phase crosswalk](phases/phase-crosswalk.md), then use the phase narrative that matches the layer you are working on.

## Status and audit documents

- [Project status](project-status.md)
- [Public and private boundary](public-private-boundary.md)
- [Public repo readiness check](install/19-public-repo-readiness-check.md)
- [Public-only validation pass](install/20-public-only-validation-pass.md)
