# Project Status, Public Completeness, and Reconciliation Truth Layer

## Scope of this comparison

This status document was built by comparing the uploaded archive roots exactly as provided for Phase 01:

- private source repo: `openbsd-self-hosting-main.zip`
- current public repo: `openbsd-mailstack-main.zip`

Comparison was performed against the archive contents, not against a live checkout.

## Snapshot summary

| Measure | Private repo | Public repo | Notes |
|---|---:|---:|---|
| Total files | 753 | 129 | Private repo is substantially broader and contains runtime-specific material. |
| Top-level phase assets | 163 under `mail-phases/` | 51 under `docs/phases/` and `scripts/phases/` | Public phase structure exists, but parity is mixed. |
| Service configuration trees | Present in multiple private directories | `services/` exists but is mostly placeholder scaffolding | Public service parity is not complete yet. |

## What is already public and usable

The public repo already has a solid framework layer:

- `README.md`, `CONTRIBUTING.md`, and `SECURITY.md`
- install docs under `docs/install/`
- architecture and phase docs under `docs/`
- phase apply and verify scripts under `scripts/phases/`
- QEMU lab and autonomous installer tooling under `maint/`
- public config examples under `config/*.example`

That means the public repo is already more than a placeholder. It has a coherent public framework and an opinionated phase model.

## What is not yet at private parity

The private repo still contains large functional areas that have not yet been published in sanitized form, including:

- service-specific configuration trees such as `postfix/`, `dovecot/`, `nginx/`, `rspamd/`, `redis/`, `suricata/`, and `firewall/`
- maintenance and diagnostics areas such as `mail-diagnostics/`, `backup-ops/`, `monitoring/`, `ddns/`, `wg/`, and `sbom/`
- runtime evidence and host-state artifacts under `evidence/`
- private phase trees and refit and upgrade variants under `mail-phases/`
- site-specific operational doctrine tied to a live deployment

The public `services/` directories currently exist mainly as placeholders. That is an explicit truth point for contributors, not a failure hidden by documentation language.

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

## Operator-input gap that existed before this patch

Before this patch, the public repo had public config examples, but it did not yet have a consistent published model for:

- ignored repo-local operator inputs
- repo-local provider env files
- host-local provider file discovery
- overlay precedence
- later phase reuse of the same input discovery logic

Also, several public phase scripts depended on shared helper functions that were not yet implemented in the shared library. This patch fixes that foundation issue.

## Functional status matrix

| Area | Private repo | Public repo before this patch | Public repo after this patch |
|---|---|---|---|
| Truth layer for completeness | Implicit in private tree structure | Missing | Added |
| Phase crosswalk | Private phase trees only | Missing | Added |
| Operator-input discovery model | Present operationally, not published here | Partial and inconsistent | Added and shared |
| Repo-safe provider examples | Private material and docs only | Partial | Expanded |
| Ignored local operator paths | Private operationally | Missing in public repo config | Added |
| Shared validation helpers | Mature private scripts | Incomplete in public common library | Expanded |
| Service config parity | Mature private trees | Not yet public | Still intentionally incomplete |
| DR artifacts and live runtime evidence | Private only | Not public | Remain private by design |

## Immediate next migration candidates

The most useful next public parity work items are:

1. publish sanitized service configuration templates for `postfix`, `dovecot`, `nginx`, `rspamd`, and related supporting services
2. publish public-safe PF and networking templates after host-specific bindings are removed
3. publish generic diagnostics and maintenance tooling from `mail-diagnostics/`, `backup-ops/`, `monitoring/`, and `sbom/`
4. selectively migrate later-phase doctrine where it can be detached from the live private host

## Non-goals of this phase

This phase does **not** claim:

- full service config parity
- publication of private DR payloads
- publication of live infrastructure evidence
- publication of real domains, credentials, or operator-specific policy
- parity for all late private control-plane behavior

That work remains for later phases.
