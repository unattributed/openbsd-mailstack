# Project Status, Public Completeness, and Reconciliation Truth Layer

## Scope of this comparison

This status document was built by comparing the uploaded archive roots exactly as provided for reconciliation work:

- private source repo: `openbsd-self-hosting-main.zip`
- current public repo: `openbsd-mailstack-main.zip`

Comparison was performed against the archive contents, not against a live checkout.

## Snapshot summary

| Measure | Private repo | Public repo | Notes |
|---|---:|---:|---|
| Total files | 753 | 129 before this phase patch | Private repo is substantially broader and contains runtime-specific material. |
| Top-level phase assets | 163 under `mail-phases/` | 51 under `docs/phases/` and `scripts/phases/` before reconciliation patches | Public phase structure exists, but parity is mixed. |
| Service configuration trees | Present in multiple private directories | Present publicly in sanitized form | Public service parity is improved, but not complete. |
| Install and ops path | Mature private install and maintenance doctrine | Publicly usable after phases 01 to 03 | Public path is now coherent through the first mail baseline. |
| Backup and DR path | Mature and host-specific | Publicly usable after phase 04 baseline | Public repo now has public-safe backup, restore, QEMU drill, and DR site provisioning assets. |
| Monitoring and diagnostics path | Mature and host-specific | Publicly usable after phase 05 baseline | Public repo now has public-safe monitoring inputs, static monitoring pages, log summaries, health reports, and install helpers. |
| Maintenance and regression path | Mature and host-specific | Publicly usable after phase 06 baseline | Public repo now has public-safe maintenance inputs, syspatch and package upgrade wrappers, regression checks, rollback guidance, and QEMU rehearsal helpers. |

## What is already public and usable

The public repo already has a solid framework layer:

- `README.md`, `CONTRIBUTING.md`, and `SECURITY.md`
- install docs under `docs/install/`
- architecture and phase docs under `docs/`
- phase apply and verify scripts under `scripts/phases/`
- QEMU lab and autonomous installer tooling under `maint/`
- public config examples under `config/*.example`
- sanitized core service templates under `services/`
- staged rendered runtime output under `services/generated/rootfs/`
- a public phase runner and post-install verification path under `scripts/install/` and `scripts/verify/`
- daily and weekly operator review scripts under `scripts/ops/`
- public-safe backup, restore, replication, and DR site provisioning helpers
- public-safe monitoring, diagnostics, log rotation, and reporting helpers
- public-safe maintenance, upgrade, regression, and rollback helpers

That means the public repo is already more than a placeholder. It now has a coherent public framework, an operator input model, a reusable runtime layer, a workable install and validation path, and a materially usable baseline for backup and DR.

## What is not yet at private parity

The private repo still contains large functional areas that have not yet been published in sanitized form, including:

- deeper maintenance and diagnostics areas such as `mail-diagnostics/`, `monitoring/`, `ddns/`, `wg/`, and `sbom/`
- runtime evidence and host-state artifacts under `evidence/`
- private phase trees and refit and upgrade variants under `mail-phases/`
- site-specific operational doctrine tied to a live deployment
- advanced monitoring site content, control-plane automation, and private off-host DR repositories

The public repo now supports backup, restore, restore drills, DR site provisioning, a practical monitoring baseline, and a public-safe maintenance and regression layer, but it still does not claim full private parity for live infrastructure evidence, private dashboards, private recovery payload handling, or private control-plane governance.

## Public phase maturity, honest view

The public repo contains phases `00` through `16`, but they are not all at the same maturity level.

### Stronger current public foundation

The earlier public phases provide more concrete structure for:

- baseline configuration
- network and exposure planning
- MariaDB
- PostfixAdmin and SQL wiring
- Postfix
- Dovecot
- TLS
- filtering
- web access
- DNS identity publishing
- operations scaffolding
- QEMU-first validation and first production deployment guidance
- backup, restore, and restore drill scaffolding

### Later public phases are still baseline-level

Several later public phases remain concise baselines rather than full private parity assets. This is especially true where the private repo contains host-specific policy, deeper live monitoring, advanced control-plane behavior, or private recovery repositories.

## What Phase 04 adds

Phase 04 adds a public-safe backup and recovery layer that a new operator can actually use:

- `config/backup.conf.example` and `config/dr-site.conf.example`
- loader support for backup and DR site operator inputs
- reusable backup helpers for config, MariaDB, and broader mailstack state
- a staged, non-destructive restore path by default
- an off-host replication helper
- a QEMU restore drill runner
- DR site provisioning assets, docs, and installer logic
- stronger phase 11 through 13 documentation and helper wiring

## What Phase 05 adds

Phase 05 adds a public-safe monitoring and diagnostics layer that a new operator can actually use:

- `config/monitoring.conf.example`
- loader support for monitoring operator inputs
- reusable monitoring, diagnostics, and reporting libraries
- monitoring collection, rendering, and reporting helpers
- generic cron-report and alert-mail wrappers
- nginx, newsyslog, and cron templates for the monitoring baseline
- stronger phase 14 documentation and helper wiring

## What Phase 06 adds

Phase 06 adds a public-safe maintenance and regression layer that a new operator can actually use:

- `config/maintenance.conf.example`
- loader support for maintenance operator inputs
- reusable maintenance preflight, report-mode, and apply-mode helpers
- public-safe `syspatch` and `pkg_add -u` wrappers
- regression checks and rollback guidance
- a weekly maintenance cron installer and cron runner
- a QEMU maintenance rehearsal helper

## Functional status matrix

| Area | Private repo | Public repo before reconciliation | Public repo after phases 01 to 06 |
|---|---|---|---|
| Truth layer for completeness | Implicit in private tree structure | Missing | Added |
| Phase crosswalk | Private phase trees only | Missing | Added |
| Operator-input discovery model | Present operationally, not published here | Partial and inconsistent | Added and shared |
| Repo-safe provider examples | Private material and docs only | Partial | Expanded |
| Ignored local operator paths | Private operationally | Missing in public repo config | Added |
| Shared validation helpers | Mature private scripts | Incomplete in public common library | Expanded |
| Core service config parity | Mature private trees | Placeholder heavy | Public-safe baseline present |
| Install and validation path | Mature and host-specific | Partial | Coherent through first public baseline |
| Daily and weekly ops path | Mature and host-specific | Partial | Public-safe baseline added |
| Backup and restore path | Mature and host-specific | Placeholder only | Public-safe baseline added |
| DR portal and restore drill path | Private and host-specific | Not public | Public-safe baseline added |
| Monitoring and reporting path | Mature and host-specific | Checklist-only baseline | Public-safe baseline added |
| Maintenance and regression path | Mature and host-specific | Baseline-only doctrine | Public-safe baseline added |
| DR artifacts and live runtime evidence | Private only | Not public | Remain private by design |

## What can now be done entirely from the public repo

A new operator can now do the following without relying on private-only files:

1. complete provider and credential onboarding
2. populate operator input files using tracked examples and ignored local paths
3. render the sanitized runtime tree under `services/generated/rootfs/`
4. test the phase path in QEMU using the existing public lab tooling
5. run the public phase sequence through the backup and DR layers
6. install staged configs onto a target OpenBSD host
7. run post-install checks and the daily and weekly operator review scripts
8. install public-safe backup helpers, create backup sets, verify them, and rehearse restore drills
9. provision a repo-managed DR site for internal recovery guidance
10. install and use a public-safe monitoring, diagnostics, and reporting baseline
11. rehearse and run public-safe maintenance, upgrade, and regression workflows

## Immediate next migration candidates

The most useful next public parity work items are:

1. publish sanitized PF and networking templates after host-specific bindings are removed
2. extend the published diagnostics and maintenance tooling from `mail-diagnostics/`, `monitoring/`, and `sbom/` where it can be generalized safely
3. selectively migrate later-phase doctrine where it can be detached from the live private host
4. publish more of the monitoring and reporting stack in a similarly public-safe form
5. selectively migrate deeper maintenance governance and upgrade control-plane behavior where it can be generalized safely

## Non-goals of this phase

This phase does **not** claim:

- publication of private off-host repositories or production snapshot payloads
- publication of live infrastructure evidence
- publication of real domains, credentials, or operator-specific policy
- parity for all late private control-plane behavior

That work remains for later phases.

## Phase 04 refinement status

The public repo now includes a unified backup runner, archive protection helper,
backup scheduling helper, and a DR host bootstrap script. Private-only snapshot
content, site-specific encrypted payloads, and host evidence are still out of
scope for publication.

## Phase 05 status

The public repo now includes a real public-safe monitoring baseline, including
operator inputs, a static monitoring site generator, health reports, cron-safe
reporting wrappers, nginx and newsyslog templates, and phase 14 apply and verify
wiring. Private dashboards, private telemetry feeds, and site-specific control
plane behavior remain outside the public scope.

## Phase 06 status

The public repo now includes a real public-safe maintenance layer, including a maintenance input example, preflight and report-mode checks, `syspatch` and `pkg_add` wrappers, regression testing, rollback guidance, a weekly maintenance cron helper, and a QEMU rehearsal path for maintenance and upgrade windows. Private change-governance policy, live operator identities, and autonomous remediation remain outside the public scope.
