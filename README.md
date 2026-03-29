# openbsd-mailstack

`openbsd-mailstack` is a public, operator-focused mail platform for OpenBSD 7.8. It provides a reproducible baseline for building and maintaining a hardened single-host mail system with Postfix, Dovecot, Rspamd, Roundcube, PostfixAdmin, optional SOGo, and supporting network and operations controls.

This repository is intended to hold reusable code, templates, documentation, and verification tooling. Site-specific credentials, private recovery data, and encrypted backup artifacts are intentionally kept out of scope.

## What this project is

This project is a phase-driven framework for building a security-focused OpenBSD mail host.

It is designed for operators who want:

- a documented install path
- a reproducible mail stack baseline
- clear separation between public code and private secrets
- verification and maintenance guidance
- safe lab testing before real deployment

It is not a one-command production mail server. It is a structured public framework that guides the operator through setup, validation, operations, backup, recovery, and hardening.

## Highlights

- OpenBSD 7.8 baseline for clean installs and controlled upgrades
- Hardened single-host mail platform with a minimal WAN exposure model
- Postfix, Dovecot, Rspamd, Roundcube, PostfixAdmin, and optional SOGo
- PF default deny and WireGuard-gated control-plane access
- Guided installer and phase-based automation for reproducible builds
- Verification, monitoring, maintenance, and backup orchestration
- Optional DNS, DDNS, smart relay, and reputation-provider integrations
- Recovery payload staging and integration hooks for private DR backends
- QEMU lab layer for disposable VM testing
- Customizable OpenBSD autonomous installer layer

## Start here

Read these in order:

1. `docs/install/README.md`
2. `docs/architecture/01-project-architecture-and-flow.md`
3. `docs/install/08-quick-start-and-usage-paths.md`

Those three documents explain:

- what the project is
- how the pieces fit together
- which path you should follow first

## Step 0, external prerequisites

Before starting the phase-driven build, complete the external prerequisite documents under `docs/install/`.

Required first documents:

- `docs/install/02-vultr-account-and-api-setup.md`
- `docs/install/03-brevo-account-and-relay-setup.md`
- `docs/install/04-virustotal-api-setup.md`
- `docs/install/05-local-provider-secret-file-layout.md`

These documents cover:

- authoritative DNS setup in Vultr
- secure creation and storage of the Vultr API key
- Brevo account creation and relay credential handling
- VirusTotal API setup and quota-aware usage
- the preferred local secret file layout under `/root/.config/`

No live provider secret should ever be committed to this repository.

## Supported deployment topologies

`openbsd-mailstack` supports both of these public deployment models:

- Single-domain mail host  
  Example: `mail.example.com` serving `example.com`
- Multi-domain mail host  
  Example: `mail.example.com` serving `example.com`, `example.net`, and `example.org`

All tracked examples in this repository use reserved domains only. Real domains, customer identities, and provider credentials must be supplied through local configuration during installation.

## Main usage paths

### Path A, documentation-first operator path

Use this when you want to understand the system and apply phases deliberately.

- complete install prerequisites
- review architecture docs
- run phases in order
- verify each phase before continuing

### Path B, QEMU lab path

Use this when you want to prototype without dedicated hardware.

- complete install prerequisites that matter to your test scope
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

This repository is public by design.

Included here:

- reusable automation
- public documentation
- example configuration
- verification and maintenance tooling
- installer and bootstrap assets
- DR interface and recovery payload generation logic

Not included here:

- real secrets, API tokens, PATs, or private keys
- real domains or customer-specific mail topology
- encrypted snapshots or restore archives
- private recovery repositories
- operator workstation state or generated install output

## Configuration model

The public configuration model treats domain topology as local operator input rather than a tracked constant.

Typical core settings:

```env
MAIL_HOST_FQDN=mail.example.com
MAIL_TOPOLOGY=single
PRIMARY_MAIL_DOMAIN=example.com
HOSTED_MAIL_DOMAINS="example.com"
```

Multi-domain example:

```env
MAIL_HOST_FQDN=mail.example.com
MAIL_TOPOLOGY=multi
PRIMARY_MAIL_DOMAIN=example.com
HOSTED_MAIL_DOMAINS="example.com example.net example.org"
```

Generated runtime configuration should derive from these values rather than from hardcoded tracked domains.

## Current public phase coverage

The public repo now includes documentation and apply and verify scripts through:

- Phase 00, foundation
- Phase 01, network and external access
- Phase 02, MariaDB baseline
- Phase 03, PostfixAdmin and SQL wiring
- Phase 04, Postfix core and SQL integration
- Phase 05, Dovecot auth and mailbox delivery
- Phase 06, TLS and certificate automation
- Phase 07, filtering and anti-abuse
- Phase 08, webmail and administrative access
- Phase 09, DNS and identity publishing
- Phase 10, operations and resilience
- Phase 11, backup and disaster recovery baseline
- Phase 12, advanced backup security and integrity
- Phase 13, off-host replication and restore testing
- Phase 14, monitoring and reporting baseline
- Phase 15, security hardening and authentication model
- Phase 16, secrets handling and key material management

## Installation model

The preferred operator experience is:

1. complete the external prerequisite documents under `docs/install/`
2. review the quick-start usage paths
3. choose a path: direct host, QEMU lab, or autonomous installer
4. provide local configuration for hostname, domain topology, networking, and optional integrations
5. apply the phase-driven build and verification flow
6. enable optional provider integrations only after the core mail path passes verification

## Next major documentation gap

The public repo now covers phase content through Phase 16. The next major work item is to reconcile and publish the remaining private-repo phases and operational doctrine from the original `openbsd-self-hosting` project, especially the original later-phase material beyond the early public baseline.

## Project policies

- Security reporting: see `SECURITY.md`
- Contribution guidance: see `CONTRIBUTING.md`
