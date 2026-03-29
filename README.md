# openbsd-mailstack

`openbsd-mailstack` is a public, operator-focused mail platform framework for OpenBSD 7.8. It publishes reusable documentation, scripts, templates, and verification tooling for a hardened single-host mail system built around Postfix, Dovecot, Rspamd, Roundcube, PostfixAdmin, and supporting network and operations controls.

This repository is public by design. It is not a mirror of the private `openbsd-self-hosting` repo, but it now provides a materially complete public-safe baseline for building the same class of server with operator-supplied data.

## What this project is

This project is a phase-driven public framework for building and maintaining a security-focused OpenBSD mail host.

It is designed for operators who want:

- a documented install path
- a reproducible baseline
- clear separation between public code and private data
- verification and maintenance guidance
- safe lab testing before real deployment

It is not a one-command production mail server. It is a structured public repo that guides the operator through setup, validation, operations, backup, recovery planning, hardening, and host-local secret handling.

## Start here

Read these in order:

1. `docs/project-status.md`
2. `docs/phases/phase-crosswalk.md`
3. `docs/install/README.md`
4. `docs/architecture/01-project-architecture-and-flow.md`
5. `docs/install/08-quick-start-and-usage-paths.md`
6. `docs/install/09-install-order-and-phase-sequence.md`
7. `docs/install/21-security-hardening-and-runtime-secrets.md`

## Current public completeness

The public repo currently contains:

- install and architecture documentation
- phase docs and apply and verify scripts through Phase 16
- QEMU lab and autonomous installer tooling
- config examples and public-safe generated fragments
- daily and weekly operator workflow scripts
- backup, DR, monitoring, maintenance, and network exposure helpers
- advanced optional Suricata, Brevo, SOGo, and SBOM assets
- runnable hardening helpers for `doas` and SSH
- runnable host-local runtime secret layout helpers

## What remains intentionally private or operator-supplied

The remaining boundaries are specific:

- live production evidence, restore archives, and site-specific control-plane doctrine remain private
- provider-specific integrations beyond the published public-safe set are not generalized here
- operators must still supply their own identities, secrets, private keys, and exposure policy locally

That is the intended public model.

## Operator input model

The public repo supports a consistent operator-input discovery model.

Tracked examples include:

- `config/system.conf.example`
- `config/network.conf.example`
- `config/domains.conf.example`
- `config/secrets.conf.example`
- `config/security.conf.example`
- `config/secrets-runtime.conf.example`

Ignored local inputs include:

- `config/*.conf` for real local values
- `config/local/`
- protected host-local files under `/root/.config/openbsd-mailstack/`

## Practical outcome

With operator-supplied domains, network values, provider accounts, API keys, and host-local secret files, this repo now provides a public-safe path to build and operate a full OpenBSD mail stack of the same class as the private deployment.
