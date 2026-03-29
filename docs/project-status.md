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
| Top-level phase assets | 163 under `mail-phases/` | 51 under `docs/phases/` and `scripts/phases/` before this phase patch | Public phase structure exists, but parity is mixed. |
| Service configuration trees | Present in multiple private directories | Present publicly in sanitized form | Public service parity is improved, but not complete. |
| Install and ops path | Mature private install and maintenance doctrine | Publicly usable after phases 01 to 03 | Public path is now coherent through the first mail baseline. |

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

That means the public repo is already more than a placeholder. It now has a coherent public framework, an operator input model, a reusable runtime layer, and a workable install and validation path.

## What is not yet at private parity

The private repo still contains large functional areas that have not yet been published in sanitized form, including:

- deeper maintenance and diagnostics areas such as `mail-diagnostics/`, `backup-ops/`, `monitoring/`, `ddns/`, `wg/`, and `sbom/`
- runtime evidence and host-state artifacts under `evidence/`
- private phase trees and refit and upgrade variants under `mail-phases/`
- site-specific operational doctrine tied to a live deployment
- advanced monitoring site content, control-plane automation, and DR payloads

The public repo now supports the first install and operations path, but it does not yet claim the full private maintenance and resilience stack.

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

### Later public phases are still baseline-level

The later public phases are useful planning scaffolds, but several remain concise public baselines rather than reconciled parity assets from the private repo.

This is especially true where the private repo contains:

- host-specific operational policy
- disaster recovery implementation details
- monitoring and enforcement controls
- upgrade-path doctrine
- advanced control-plane behavior

## What Phase 01 adds

This patch closes an important public-foundation gap without pretending to finish parity.

It adds:

- the status truth layer in this document
- a private-to-public crosswalk in `docs/phases/phase-crosswalk.md`
- an explicit private boundary document in `docs/public-private-boundary.md`
- a documented operator-input model
- ignored local config paths under `config/`
- repo-safe provider examples under `config/examples/providers/`
- a shared loader in `scripts/lib/operator-inputs.ksh`
- expanded shared validation and config-writing helpers in `scripts/lib/common.ksh`

## What Phase 02 adds

Phase 02 adds public-safe core runtime templates and shared rendering and installation helpers for MariaDB, PostfixAdmin, Postfix, Dovecot, nginx, Roundcube, Rspamd, Redis, ClamAV, and FreshClam. This improves the public repo from mostly generated example fragments to a reusable staged rootfs model under `services/generated/rootfs/`, driven by operator input files and helper scripts.

## What Phase 03 adds

Phase 03 makes the public repo materially easier for a new operator to use.

It adds:

- a documented install order and phase execution model
- a QEMU-first validation path that fits the public repo
- a first production deployment sequence based only on public-safe assets
- post-install validation guidance and a reusable post-install check script
- daily and weekly operator workflow docs and helper scripts
- clearer statements about what the public repo can now do end-to-end and what remains optional or advanced

## Functional status matrix

| Area | Private repo | Public repo before reconciliation | Public repo after phases 01 to 03 |
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
| DR artifacts and live runtime evidence | Private only | Not public | Remain private by design |

## What can now be done entirely from the public repo

A new operator can now do the following without relying on private-only files:

1. complete provider and credential onboarding
2. populate operator input files using tracked examples and ignored local paths
3. render the sanitized runtime tree under `services/generated/rootfs/`
4. test the phase path in QEMU using the existing public lab tooling
5. run the public phase sequence, normally through Phase 10 for the first baseline
6. install staged configs onto a target OpenBSD host
7. run post-install checks and reuse the daily and weekly operator review scripts

## Immediate next migration candidates

The most useful next public parity work items are:

1. publish sanitized PF and networking templates after host-specific bindings are removed
2. publish public-safe diagnostics and maintenance tooling from `mail-diagnostics/`, `backup-ops/`, `monitoring/`, and `sbom/`
3. selectively migrate later-phase doctrine where it can be detached from the live private host
4. publish more of the backup and DR workflow once secrets and infrastructure-specific assumptions are removed

## Non-goals of this phase

This phase does **not** claim:

- full service config parity
- publication of private DR payloads
- publication of live infrastructure evidence
- publication of real domains, credentials, or operator-specific policy
- parity for all late private control-plane behavior

That work remains for later phases.
