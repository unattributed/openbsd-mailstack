# openbsd-mailstack

`openbsd-mailstack` is a public, operator-focused mail platform for OpenBSD 7.8. It provides a reproducible baseline for building and maintaining a hardened single-host mail system with Postfix, Dovecot, Rspamd, Roundcube, PostfixAdmin, optional SOGo, and supporting network and operations controls.

This repository is intended to hold reusable code, templates, documentation, and verification tooling. Site-specific credentials, private recovery data, and encrypted backup artifacts are intentionally kept out of scope.

## Highlights

- OpenBSD 7.8 baseline for clean installs and controlled upgrades
- Hardened single-host mail platform with a minimal WAN exposure model
- Postfix, Dovecot, Rspamd, Roundcube, PostfixAdmin, and optional SOGo
- PF default deny and WireGuard-gated control-plane access
- Guided installer and phase-based automation for reproducible builds
- Verification, monitoring, maintenance, and backup orchestration
- Optional DNS/DDNS, smart relay, and reputation-provider integrations
- Recovery payload staging and integration hooks for private DR backends

## Step 0, External Prerequisites

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

## Supported Deployment Topologies

`openbsd-mailstack` supports both of these public deployment models:

- Single-domain mail host
  - Example: `mail.example.com` serving `example.com`
- Multi-domain mail host
  - Example: `mail.example.com` serving `example.com`, `example.net`, and `example.org`

All tracked examples in this repository use reserved domains only. Real domains, customer identities, and provider credentials must be supplied through local configuration during installation.

## Core Components

- Mail transport: Postfix
- Mail access and delivery: Dovecot
- Filtering and scoring: Rspamd, Redis, ClamAV
- Administration and webmail: PostfixAdmin, Roundcube
- Groupware: optional SOGo
- Network and access control: PF, WireGuard, Unbound
- Operations: verification, monitoring, maintenance, backup, and SBOM tooling

## Repository Boundary

This repository is public by design.

Included here:

- Reusable automation
- Public documentation
- Example configuration
- Verification and maintenance tooling
- Installer and bootstrap assets
- DR interface and recovery payload generation logic

Not included here:

- Real secrets, API tokens, PATs, or private keys
- Real domains or customer-specific mail topology
- Encrypted snapshots or restore archives
- Private recovery repositories
- Operator workstation state or generated install output

## Configuration Model

The public configuration model should treat domain topology as local operator input rather than a tracked constant.

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

## Installation Model

The preferred operator experience is:

1. Complete the external prerequisite documents under `docs/install/`.
2. Start with a clean OpenBSD 7.8 host.
3. Use the guided installer or bootstrap workflow to generate host-local install assets.
4. Provide local configuration for hostname, domain topology, networking, and optional integrations.
5. Apply the phase-driven build and verification flow.
6. Enable optional provider integrations only after the core mail path passes verification.

The public repo should support:

- a simple guided path for first-time operators
- an advanced phase-by-phase path for experienced sysadmins
- clear verification gates after install and after major changes

## Disaster Recovery Model

`openbsd-mailstack` is responsible for building a recovery-capable mail host and generating the artifacts required for disaster recovery.

Recommended separation of responsibilities:

- `openbsd-mailstack`
  - public stack build
  - configuration templates
  - verification and maintenance tooling
  - recovery payload staging
  - DR integration hooks
- private DR backend
  - encrypted snapshots
  - recovery media contents
  - restore workflows
  - site-specific credentials and operator secrets

This separation allows the operational codebase to remain public while keeping backups, recovery materials, and trust anchors private.

## Security Posture

The intended baseline is security-first and operator-auditable:

- minimal WAN exposure
- PF default deny
- WireGuard-restricted control-plane access
- host-local secret storage only
- explicit verification after install, maintenance, and upgrade operations
- strict separation between public automation and private recovery assets

## Project Status

`openbsd-mailstack` is intended to be the public successor to an internal operations repository. The target public baseline is a reproducible OpenBSD 7.8 mail platform with a documented install flow, verification gates, and a clean boundary between public stack code and private DR state.

## Project Policies

- Security reporting: see `SECURITY.md`
- Contribution guidance: see `CONTRIBUTING.md`
