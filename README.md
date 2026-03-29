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

## Start here

Read these in order:

1. `docs/project-status.md`
2. `docs/phases/phase-crosswalk.md`
3. `docs/install/README.md`
4. `docs/architecture/01-project-architecture-and-flow.md`
5. `docs/install/08-quick-start-and-usage-paths.md`

Those documents explain:

- what is already public
- what is still missing or intentionally private
- how private phases map to the public phase model
- where to place operator-provided data safely

## Current public completeness

The public repo currently contains:

- install and architecture documentation
- phase docs and apply and verify scripts through Phase 16
- QEMU lab and autonomous installer tooling
- config examples and public-safe generated fragments
- repository policy files such as `CONTRIBUTING.md` and `SECURITY.md`

The public repo does **not** yet provide full private parity.

Important current limits:

- several private service configuration trees are now published in sanitized form for the core mail runtime
- the public `services/` tree now contains real service templates, but later operational areas are still lighter than private parity
- later public phases still exist with uneven depth, especially outside the core mail runtime and web plane
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
3. choose a path: direct host, QEMU lab, or autonomous installer
4. run phases in order
5. verify each phase before moving forward
6. publish or expose optional integrations only after the core mail path passes verification

## What remains to migrate

The next migration waves should focus on sanitized public publication of:

- deeper parity for PF, monitoring, backup, diagnostics, and DR automation
- additional operational doctrine and hardened maintenance tooling
- selected later-phase operational doctrine once host-specific policy is removed
- optional SOGo and advanced operations material where public-safe parity is practical

The crosswalk in `docs/phases/phase-crosswalk.md` is the planning baseline for that work.

## Project policies

- Security reporting: see `SECURITY.md`
- Contribution guidance: see `CONTRIBUTING.md`
