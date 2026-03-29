# openbsd-mailstack

`openbsd-mailstack` is a public, operator-focused mail platform framework for OpenBSD 7.8. It publishes reusable documentation, scripts, templates, staged rendered assets, and verification tooling for a hardened single-host mail system built around Postfix, Dovecot, Rspamd, Roundcube, PostfixAdmin, and supporting network and operations controls.

This repository is public by design. It is not a byte-for-byte mirror of the private `openbsd-self-hosting` repo. It does provide a materially usable public-safe baseline through the documented public phases, while keeping live secrets, live evidence, and real recovery payloads out of scope.

## What this project is

This project is a phase-driven public framework for building, validating, operating, and recovering an OpenBSD mail host.

It is designed for operators who want:

- a documented prerequisite and install path
- a reproducible baseline with tracked templates and generated examples
- clear separation between public code and private operator data
- verification, monitoring, maintenance, backup, and recovery guidance
- safe lab testing before real deployment

It is not a one-command production mail server. It is a structured public repo that guides the operator through setup, validation, operations, backup, recovery planning, and hardening.

## Current public baseline

The public repo now includes a public-safe baseline for:

- phased apply and verify scripts through Phase 17
- core mail runtime templates for MariaDB, PostfixAdmin, Postfix, Dovecot, nginx, Roundcube, Rspamd, Redis, ClamAV, and FreshClam
- QEMU lab and autonomous installer workflows
- network exposure control with PF, WireGuard, Unbound, and Vultr DDNS templates and helpers
- backup, restore, DR portal, and DR host bootstrap workflows
- monitoring, diagnostics, logging, reporting, maintenance, and regression helpers
- optional Suricata, Brevo webhook, SOGo, and SBOM workflows

## Start here

Read these in order for a new deployment:

1. `docs/project-status.md`
2. `docs/phases/phase-crosswalk.md`
3. `docs/install/README.md`
4. `docs/architecture/01-project-architecture-and-flow.md`
5. `docs/install/08-quick-start-and-usage-paths.md`
6. `docs/install/09-install-order-and-phase-sequence.md`
7. `docs/install/19-public-repo-readiness-check.md`

Those documents tell you:

- what the public repo includes today
- what remains intentionally private or partially documented
- how private layers were generalized into public-safe operator inputs
- how to move from prerequisites, to lab validation, to first deployment, to day-2 operations

## Operator discovery map

Use these public docs when you need a specific path:

- prerequisites, `docs/install/README.md`
- install order, `docs/install/09-install-order-and-phase-sequence.md`
- QEMU and test path, `docs/install/06-qemu-lab-and-vm-testing.md` and `docs/install/10-qemu-first-validation-path.md`
- first deployment path, `docs/install/11-first-production-deployment-sequence.md`
- post-install checks, `docs/install/12-post-install-checks.md`
- backup path, `docs/12-backup-and-disaster-recovery.md` and `docs/install/14-backup-and-restore-drill-sequence.md`
- recovery and DR path, `docs/install/13-dr-site-provisioning.md` and `docs/install/15-dr-host-bootstrap.md`
- monitoring and diagnostics path, `docs/install/16-monitoring-diagnostics-and-reporting.md`
- maintenance and regression path, `docs/install/17-maintenance-upgrades-regression-and-rollback.md`
- optional advanced path, `docs/install/18-advanced-optional-integrations-and-gap-closures.md`
- final readiness audit, `docs/install/19-public-repo-readiness-check.md`

## Current public completeness

The public repo currently contains:

- install, architecture, security, and operations documentation
- phase docs and apply and verify scripts through Phase 17
- tracked public-safe operator input examples under `config/`
- QEMU lab and autonomous installer tooling under `maint/`
- staged generated service fragments under `services/generated/`
- verification, monitoring, backup, restore, maintenance, and audit helpers under `scripts/` and `maint/`

The public repo does **not** include:

- real secrets, tokens, PATs, or private keys
- real domains, hostnames, IPs, or peer material tied to live infrastructure
- encrypted DR snapshots, live mailbox data, or database dumps
- live runtime evidence, incident data, or production telemetry exports
- site-specific control-plane policy that cannot be generalized safely

See `docs/project-status.md` for the evidence-based completeness assessment.

## Operator input model

The public repo uses a consistent operator-input discovery model.

Tracked examples include:

- `config/system.conf.example`
- `config/network.conf.example`
- `config/domains.conf.example`
- `config/secrets.conf.example`
- `config/dns.conf.example`
- `config/ddns.conf.example`
- `config/backup.conf.example`
- `config/monitoring.conf.example`
- `config/maintenance.conf.example`
- `config/suricata.conf.example`
- `config/brevo-webhook.conf.example`
- `config/sogo.conf.example`
- `config/sbom.conf.example`
- `config/examples/providers/*.env.example`

Ignored local inputs include:

- `config/*.conf`
- `config/local/`
- protected host-local files under `/root/.config/openbsd-mailstack/`

The shared loader in `scripts/lib/operator-inputs.ksh` reads values from those locations in deterministic order. Later apply and verify scripts reuse the same shared logic through `scripts/lib/common.ksh`.

## Supported deployment models

`openbsd-mailstack` supports both of these public deployment models:

- single-domain mail host
- multi-domain mail host

All tracked examples use reserved domains only. Real domains, customer identities, provider credentials, and host-specific values must be supplied through local operator input files.

## Main usage paths

### Documentation-first path

Use this when you want to understand the system and apply phases deliberately.

- complete install prerequisites
- review architecture and status docs
- run phases in order
- verify each phase before continuing

### QEMU lab path

Use this when you want to prototype without dedicated hardware.

- complete the prerequisite docs that matter to your test scope
- review `docs/install/06-qemu-lab-and-vm-testing.md`
- build a disposable OpenBSD VM
- run selected phases inside the VM
- collect reports before changing a real host

### Autonomous installer path

Use this when you want to generate a reusable OpenBSD autoinstall pack.

- review `docs/install/07-openbsd-autonomous-installer.md`
- build a local installer profile
- render the install pack
- serve it over HTTP
- use it for lab or real hardware installs

## Core components

- Mail transport, Postfix
- Mail access and delivery, Dovecot
- Filtering and scoring, Rspamd, Redis, ClamAV
- Administration and webmail, PostfixAdmin and Roundcube
- Groupware, optional SOGo with public-safe templates and staged assets
- Network and access control, PF, WireGuard, Unbound, and DDNS helpers
- Operations, verification, monitoring, maintenance, backup, restore, DR, and SBOM tooling

## Repository boundary

Included here:

- reusable automation
- public documentation and runbooks
- example configuration and staged rendered fragments
- verification, monitoring, and maintenance tooling
- installer, bootstrap, backup, recovery, and audit helpers

Not included here:

- real secrets, API tokens, PATs, or private keys
- real domains, hostnames, IPs, or webhook endpoints tied to active infrastructure
- encrypted snapshots, restore archives, or database dumps
- live runtime evidence from private deployments
- operator workstation state or generated host-local output

See `docs/public-private-boundary.md` for the detailed boundary table.

## Installation model

The preferred operator flow is:

1. complete the install prerequisites under `docs/install/`
2. create local operator input files from the tracked examples
3. render and review the staged configs
4. validate in QEMU where practical
5. run phases in order, usually through Phase 10 for the first public baseline
6. add backup, monitoring, maintenance, and optional advanced layers deliberately
7. run the final readiness audit before treating the repo as your primary operator reference

## Exact remaining gaps

The remaining public gaps are specific, not vague:

- phases 15 and 16 remain more documentation-led than automation-led
- live production evidence, recovery archives, and site-specific control-plane doctrine remain intentionally private
- provider-specific integrations beyond the published public-safe set are not generalized here
- public-safe examples are reusable, but operators still need to supply their own identities, secrets, and exposure policy

The crosswalk in `docs/phases/phase-crosswalk.md` and the final readiness check in `docs/install/19-public-repo-readiness-check.md` are the best current summary of what is finished and what is intentionally left out.
