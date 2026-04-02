# Public and Private Boundary

## Purpose

This document records what must stay private, what can be published after sanitization, and what is already public-safe.

The goal is to keep the public repo useful without leaking live deployment data or over-preserving private boundaries that are not actually necessary.

Live operator-generated renders and reports now belong under gitignored `.work/` paths by default, not in tracked publishable trees.

## Boundary categories

### Category A, must remain private

These items should not be published in this repo:

- real domains, hostnames, email addresses, and public IPs tied to active infrastructure
- API keys, SMTP credentials, PATs, passwords, tokens, and session material
- private keys, DKIM private keys, WireGuard private keys, TLS private keys, and trust anchors
- webhook endpoints and other provider callback URLs tied to active services
- encrypted DR snapshots, restore archives, database dumps, and mailbox archives
- live runtime evidence, logs, forensic output, and production inventory exports
- operator workstation state and personal environment files

### Category B, publish after sanitization

These items should usually become public once host-specific values are removed:

- service configuration templates
- generic PF and networking templates
- generalized monitoring and diagnostics scripts
- backup and maintenance orchestration that does not reveal private storage targets
- sanitized phase doctrine
- generic Suricata, Rspamd, Postfix, Dovecot, nginx, and Roundcube integration assets
- host-safe `doas`, SSH hardening, and runtime secret layout tooling

### Category C, already public-safe

These items are appropriate to publish now:

- docs, runbooks, architecture notes, and quick-start guidance
- apply and verify scripts that expect operator-provided local inputs
- repo-safe config examples
- generated fragments that use reserved domains and placeholder values
- loader and validation logic for local configuration discovery
- `doas` and SSH hardening helpers that avoid private identities by using operator inputs
- host-local secret layout helpers that render examples rather than live values

## Decision rule

When reconciling private material into the public repo, ask this first:

Can the behavior be expressed with reserved domains, placeholders, and operator-provided local inputs?

- If yes, publish it.
- If yes but the file still contains live values, sanitize it and then publish it.
- If no because it would expose real secrets, real mail data, or live incident evidence, keep it private and document the boundary.

## Exact remaining private boundaries

The remaining private boundaries are now specific:

- live production evidence and incident artifacts
- encrypted DR payloads and restore archives
- real operator identities, passwords, PATs, API tokens, and private keys
- site-specific control-plane doctrine tied to a real deployment
- provider-specific integrations that have not been generalized into operator-input-driven public-safe workflows


## Live backup and DR planning outputs

Backup and DR planning output is now written into the gitignored live workspace under `.work/backup-dr/`. These artifacts are operator-specific working material, not tracked publishable repo examples.
