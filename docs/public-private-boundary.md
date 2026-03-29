# Public and private boundary

## Purpose

This document records what must stay private, what can be published after sanitization, and what is already public-safe.

The goal is to keep the public repo useful without leaking live deployment data or preserving unnecessary private boundaries that could have been generalized safely.

## Boundary categories

### Category A, must remain private

These items must not be published in this repo:

- real domains, hostnames, email addresses, and public IPs tied to active infrastructure
- API keys, SMTP credentials, PATs, passwords, tokens, and session material
- private keys, DKIM private keys, WireGuard private keys, TLS private keys, and trust anchors
- webhook endpoints and other provider callback URLs tied to active services
- encrypted DR snapshots, restore archives, database dumps, and mailbox archives
- live runtime evidence, logs, forensic output, and production inventory exports
- operator workstation state and personal environment files

These are true private boundaries. Public replacements should use:

- onboarding docs
- repo-safe example files
- ignored local input paths
- generated templates with reserved domains and operator-provided values

### Category B, publish after sanitization

These items should become public when host-specific values are removed:

- service configuration templates
- generic PF and networking templates
- generalized monitoring and diagnostics scripts
- backup and maintenance orchestration that does not reveal private storage targets
- sanitized phase doctrine
- generic Suricata, Rspamd, Postfix, Dovecot, nginx, Roundcube, Brevo webhook, SOGo, and SBOM integration assets

These are not inherently private. They are only private until live details are removed.

### Category C, already public-safe

These items are appropriate to publish now:

- docs, runbooks, architecture notes, and quick-start guidance
- apply and verify scripts that expect operator-provided local inputs
- repo-safe config examples
- generated fragments that use reserved domains and placeholder values
- loader and validation logic for local configuration discovery
- QEMU lab helpers and autonomous installer tooling that avoid live host data

## Explicit boundary table

| Item type | Public-safe now | Publish later after sanitization | Must remain private |
|---|---|---|---|
| Phase docs and public runbooks | Yes | Yes | No |
| Service templates with reserved domains | Yes | Yes | No |
| Real provider credentials | No | No | Yes |
| Protected local operator files | No | No | Yes |
| DR snapshots and database dumps | No | No | Yes |
| Live logs and evidence bundles | No | No | Yes |
| Generic backup orchestration | Yes | Yes | No |
| Host-specific operational policy tied to a live deployment | No | Possibly, after generalization | Sometimes |
| Control-plane automation with live host assumptions | No | Yes, after decoupling | Sometimes |
| Reserved-domain examples | Yes | Yes | No |

## Current public-safe replacements

Where the private repo uses live values, the public repo now prefers:

- `config/*.example` for tracked examples
- `config/examples/providers/*.env.example` for provider examples
- ignored repo-local files such as `config/system.conf`
- ignored overlay files such as `config/local/providers/*.env`
- protected host-local files under `/root/.config/openbsd-mailstack/`

## Final boundary assessment

After the final public audit, the remaining private-only boundaries are narrow and explicit:

- production evidence and telemetry exports
- production DR payloads and mailbox content
- real trust anchors and live credentials
- live peer material and DNS zones tied to active infrastructure
- site-specific control-plane policy that cannot be generalized safely

Everything else should be judged by one rule:

Can the behavior be expressed with reserved domains, placeholders, and operator-provided local inputs?

- If yes, publish it.
- If yes but the current file still contains live values, sanitize it and then publish it.
- If no because publishing it would expose real secrets, real mail data, or live incident evidence, keep it private and document the boundary here.
