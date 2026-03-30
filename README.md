# openbsd-mailstack

`openbsd-mailstack` is a public, operator-focused framework for building and maintaining a hardened OpenBSD 7.8 mail platform.

It publishes reusable documentation, configuration examples, phase scripts, maintenance helpers, and staged rendered assets for a single-host mail system built around:

- Postfix
- Dovecot
- Rspamd
- Roundcube
- PostfixAdmin
- MariaDB
- Redis
- ClamAV and FreshClam
- PF, WireGuard, DNS, and DDNS

It also includes public-safe operational layers for QEMU validation, autonomous install preparation, backup and recovery, monitoring, maintenance, security hardening, runtime secret handling, and optional Suricata, Brevo, SOGo, and SBOM workflows.

## What this repository is, and is not

This repository is public by design.

It is not a literal mirror of the private `openbsd-self-hosting` repository, and it does not publish live production secrets, evidence, restore archives, or site-specific control-plane doctrine.

It is a materially complete public-safe baseline for building the same class of OpenBSD mail server with operator-supplied:

- domains and hostnames
- network and exposure values
- provider accounts and API credentials
- host-local runtime secrets and private keys
- final hardening and exposure choices

## Start here

Read these in order:

1. [Project status](docs/project-status.md)
2. [Phase crosswalk](docs/phases/phase-crosswalk.md)
3. [Documentation map](docs/README.md)
4. [Install guide](docs/install/README.md)
5. [Architecture and flow](docs/architecture/01-project-architecture-and-flow.md)
6. [Quick start and usage paths](docs/install/08-quick-start-and-usage-paths.md)
7. [Install order and phase sequence](docs/install/09-install-order-and-phase-sequence.md)
8. [Public repo readiness check](docs/install/19-public-repo-readiness-check.md)
9. [Public-only validation pass](docs/install/20-public-only-validation-pass.md)
10. [Security hardening and runtime secrets](docs/install/21-security-hardening-and-runtime-secrets.md)

## Documentation map

Use these sections as the main navigation layer:

- [Install docs](docs/install/README.md)
- [Phase docs](docs/phases/phase-crosswalk.md)
- [Operator docs](docs/operations/01-operator-workflow.md)
- [Architecture docs](docs/architecture/01-project-architecture-and-flow.md)
- [Configuration wiring](docs/configuration/core-runtime-and-config-wiring.md)
- [Project status and boundaries](docs/project-status.md)

## Current public scope

The public repository now contains:

- phase documentation and apply and verify scripts through Phase 17
- a core runtime rendering path for mail, web, filtering, and SQL services
- QEMU lab and autonomous installer tooling
- tracked config examples and ignored local input paths
- backup, disaster recovery, monitoring, maintenance, and network exposure helpers
- public-safe hardening and runtime secret layout helpers
- optional Suricata, Brevo, SOGo, and SBOM layers
- tracked sanitized rendered examples under `services/generated/rootfs/`
- a gitignored live core runtime render workspace under `.work/runtime/rootfs/`, with secret-bearing files forced to mode `0600` during render and install

## Practical operator outcome

With operator-provided data and external account setup, a new operator can use the public repository to:

1. create local input files and provider credential files
2. render the live core runtime and review `.work/runtime/rootfs/`
3. validate the baseline in QEMU
4. apply and verify the phased deployment path on a real OpenBSD host
5. run post-install checks, operations checks, maintenance checks, and backup workflows
6. add optional advanced layers only when the base system is stable

## Operator input model

Tracked examples live under `config/`.

The most important examples are:

- `config/system.conf.example`
- `config/network.conf.example`
- `config/domains.conf.example`
- `config/secrets.conf.example`
- `config/security.conf.example`
- `config/secrets-runtime.conf.example`
- `config/dns.conf.example`
- `config/ddns.conf.example`
- `config/backup.conf.example`
- `config/monitoring.conf.example`
- `config/maintenance.conf.example`

Real values belong in ignored local files such as:

- `config/local/*.conf`
- `/root/.config/openbsd-mailstack/*.conf`
- provider-specific ignored env files documented in the install docs

See:

- [Provider onboarding](docs/install/provider-account-and-credential-onboarding.md)
- [User input file layout](docs/install/user-input-file-layout.md)
- [Configuration examples](config/examples/README.md)

## Intentional boundaries

The public repository still intentionally excludes:

- live production evidence and operational telemetry from the private deployment
- encrypted recovery payloads and private restore archives
- real API keys, PATs, passwords, private keys, and runtime secret values
- site-specific control-plane doctrine and private automation overlays
- provider-specific integrations beyond the published public-safe set

Those are design boundaries, not undocumented defects.

## Validation and maintenance entry points

Useful commands after the repository is populated with local inputs:

```sh
./scripts/install/render-core-runtime-configs.ksh
./scripts/install/run-phase-sequence.ksh --phase-start 0 --phase-end 10
./scripts/verify/run-post-install-checks.ksh
./maint/final-public-validation-pass.ksh
```

## Repository companions

- `SECURITY.md` for reporting security issues
- `CONTRIBUTING.md` for contribution expectations


## Community issue intake

Use the repository issue templates for bugs, documentation gaps, and operator validation reports. Do not post secrets, private keys, tokens, or sensitive host details in public issues. Use the repository security policy for sensitive disclosures.
