# openbsd-mailstack

`openbsd-mailstack` is a public, operator-focused mail platform framework for OpenBSD 7.8. It publishes reusable documentation, scripts, templates, and verification tooling for a hardened single-host mail system built around Postfix, Dovecot, Rspamd, Roundcube, PostfixAdmin, and supporting network and operations controls.

This repository is public by design. It is not a mirror of the private `openbsd-self-hosting` repo, and it does not claim full private parity yet.

## What this project is

This project is a phase-driven public framework for building and maintaining a security-focused OpenBSD mail host.

It is designed for operators who want:

- a documented install path
- a reproducible baseline
- clear separation between public code and private data
- verification and maintenance guidance
- safe lab testing before real deployment

It is not a one-command production mail server. It is a structured public repo that guides the operator through setup, validation, operations, backup, recovery planning, and hardening.

## What changed in the phase 01 parity foundation

This phase adds the public truth layer for reconciliation work and the operator input model that later phases depend on.

## What changed in phase 02 core runtime and config wiring

This phase turns the public service layer from mostly placeholder scaffolding into a reusable runtime baseline. It adds sanitized service templates, a shared renderer, an install helper, and a verification helper for the core mail stack.

New runtime assets:

- `services/mariadb/`
- `services/postfixadmin/`
- `services/postfix/`
- `services/dovecot/`
- `services/nginx/`
- `services/roundcube/`
- `services/rspamd/`
- `services/redis/`
- `services/clamd/`
- `services/freshclam/`

New shared helpers:

- `scripts/install/render-core-runtime-configs.ksh`
- `scripts/install/install-core-runtime-configs.ksh`
- `scripts/verify/verify-core-runtime-assets.ksh`

The public repo still does not claim full private parity, but the core runtime layer is now materially more runnable and much closer to the private design.

New core references:

- `docs/project-status.md`
- `docs/phases/phase-crosswalk.md`
- `docs/public-private-boundary.md`
- `docs/install/provider-account-and-credential-onboarding.md`
- `docs/install/user-input-file-layout.md`

New operator-input foundation:

- ignored repo-local input files under `config/`
- ignored overlay paths under `config/local/`
- repo-safe provider examples under `config/examples/providers/`
- shared loader logic in `scripts/lib/operator-inputs.ksh`
- expanded shared validation and config-writing helpers in `scripts/lib/common.ksh`

## What changed in phase 03 install, test, and operations path

This phase connects the public runtime layer into a usable operator path.

New public-safe workflow assets:

- `docs/install/09-install-order-and-phase-sequence.md`
- `docs/install/10-qemu-first-validation-path.md`
- `docs/install/11-first-production-deployment-sequence.md`
- `docs/install/12-post-install-checks.md`
- `docs/operations/02-daily-operator-workflow.md`
- `docs/operations/03-weekly-operator-workflow.md`
- `scripts/install/run-phase-sequence.ksh`
- `scripts/verify/run-post-install-checks.ksh`
- `scripts/ops/daily-operator-review.ksh`
- `scripts/ops/weekly-operator-review.ksh`

The public repo can now guide a new operator through:

- prerequisites and operator input setup
- staged core runtime rendering
- QEMU-first validation
- baseline phase execution through the first production-ready mail path
- post-install validation
- daily and weekly review workflows

Later advanced operations areas still remain lighter than private parity.

## Start here

Read these in order:

1. `docs/project-status.md`
2. `docs/phases/phase-crosswalk.md`
3. `docs/install/README.md`
4. `docs/architecture/01-project-architecture-and-flow.md`
5. `docs/install/08-quick-start-and-usage-paths.md`
6. `docs/install/09-install-order-and-phase-sequence.md`

Those documents explain:

- what is already public
- what is still missing or intentionally private
- how private phases map to the public phase model
- where to place operator-provided data safely
- how to move from lab validation to first production deployment

## Current public completeness

The public repo currently contains:

- install and architecture documentation
- phase docs and apply and verify scripts through Phase 16
- QEMU lab and autonomous installer tooling
- config examples and public-safe generated fragments
- repository policy files such as `CONTRIBUTING.md` and `SECURITY.md`
- a shared phase sequence runner and post-install verification path
- daily and weekly operator workflow scripts

The public repo does **not** yet provide full private parity.

Important current limits:

- the public runtime and install path are now coherent through the first mailstack baseline, but later operations areas are still lighter than the private repo
- later public phases still exist with uneven depth, especially outside the core mail runtime, backup and DR, monitoring, and advanced control-plane behavior
- private DR payloads, live evidence, runtime inventories, and production secrets remain intentionally out of scope

See `docs/project-status.md` for the comparison details.

## Operator input model

The public repo now supports a consistent operator-input discovery model.

Tracked examples:

- `config/system.conf.example`
- `config/network.conf.example`
- `config/domains.conf.example`
- `config/secrets.conf.example`
- `config/examples/providers/*.env.example`

Ignored local inputs:

- `config/system.conf`
- `config/network.conf`
- `config/domains.conf`
- `config/secrets.conf`
- `config/local/`
- protected host-local files under `/root/.config/openbsd-mailstack/`

The shared loader in `scripts/lib/operator-inputs.ksh` reads values from those locations in a deterministic order. Later apply and verify scripts source the same shared logic through `scripts/lib/common.ksh`.

See `docs/install/user-input-file-layout.md` for the full search order and file tree.

## Supported deployment topologies

`openbsd-mailstack` supports both of these public deployment models:

- Single-domain mail host
- Multi-domain mail host

All tracked examples use reserved domains only. Real domains, customer identities, provider credentials, and host-specific values must be supplied through local operator input files.

## Main usage paths

### Path A, documentation-first operator path

Use this when you want to understand the system and apply phases deliberately.

- complete install prerequisites
- review architecture and status docs
- run phases in order
- verify each phase before continuing

### Path B, QEMU lab path

Use this when you want to prototype without dedicated hardware.

- complete the prerequisite docs that matter to your test scope
- review `docs/install/06-qemu-lab-and-vm-testing.md`
- build a disposable OpenBSD VM
- run selected phases inside the VM
- collect reports before changing a real host

### Path C, autonomous installer path

Use this when you want to generate a reusable OpenBSD autoinstall pack.

- review `docs/install/07-openbsd-autonomous-installer.md`
- build a local installer profile
- render the install pack
- serve it over HTTP
- use it for lab or real hardware installs

## Core components

- Mail transport: Postfix
- Mail access and delivery: Dovecot
- Filtering and scoring: Rspamd, Redis, ClamAV
- Administration and webmail: PostfixAdmin, Roundcube
- Groupware: optional SOGo
- Network and access control: PF, WireGuard, Unbound
- Operations: verification, monitoring, maintenance, backup, and SBOM tooling

## Repository boundary

Included here:

- reusable automation
- public documentation
- example configuration
- verification and maintenance tooling
- installer and bootstrap assets
- public-safe helper scripts and generated fragments

Not included here:

- real secrets, API tokens, PATs, or private keys
- real domains, hostnames, IPs, or webhook endpoints tied to active infrastructure
- encrypted snapshots, restore archives, or database dumps
- live runtime evidence from private deployments
- operator workstation state or generated install output

See `docs/public-private-boundary.md` for the detailed boundary table.

## Installation model

The preferred operator flow is:

1. complete the install prerequisites under `docs/install/`
2. copy or create local operator input files
3. render and review the core runtime configs
4. validate in QEMU where practical
5. run phases in order, usually through Phase 10 for the first public baseline
6. install staged configs onto the host only after review
7. run post-install checks and keep a daily and weekly operator review cadence

## What remains to migrate

The next migration waves should focus on sanitized public publication of:

- deeper parity for PF, monitoring, backup, diagnostics, and DR automation
- additional operational doctrine and hardened maintenance tooling
- selected later-phase operational doctrine once host-specific policy is removed
- optional SOGo and advanced operations material where public-safe parity is practical

The crosswalk in `docs/phases/phase-crosswalk.md` is the planning baseline for that work.
