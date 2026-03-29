# Contributing

Thanks for contributing to `openbsd-mailstack`.

This project is a public, security-sensitive infrastructure repository. Good contributions improve repeatability, operator clarity, and security posture without leaking site-specific state into the public codebase.

## What To Contribute

Good contribution areas include:

- installation and onboarding improvements
- verification and regression tooling
- OpenBSD 7.8 compatibility and reliability fixes
- documentation clarity
- safer defaults and configuration validation
- support for both single-domain and multi-domain deployments
- cleaner public/private boundaries for DR integration

## Before You Start

Please check that your change:

- fits the public scope of this repository
- does not require committing secrets or recovery artifacts
- does not hardcode a real production domain, operator identity, or private network layout
- preserves the documented security posture

For security-sensitive findings, follow `SECURITY.md` instead of opening a normal issue or pull request first.

## Public Repository Rules

The public repo must contain only reusable, non-production material.

Do:

- use reserved domains such as `example.com`, `example.net`, and `example.org`
- use placeholder credentials and clearly marked examples
- keep domain topology configurable through local inputs
- document whether a feature is core, optional, or site-specific

Do not:

- commit real secrets, PATs, API keys, or private keys
- commit generated installer output, recovery staging data, or encrypted snapshots
- commit operational evidence from live private systems unless fully sanitized and intentionally published
- hardcode a single operator name, workstation path, or production hostname as the public default

## Configuration Expectations

Contributions should preserve support for both:

- single-domain deployments
- multi-domain deployments

Tracked examples should remain neutral. Runtime values such as:

- `MAIL_HOST_FQDN`
- `MAIL_TOPOLOGY`
- `PRIMARY_MAIL_DOMAIN`
- `HOSTED_MAIL_DOMAINS`

should come from local configuration, not from baked-in production defaults.

## Code Style

Keep changes simple, explicit, and operator-auditable.

- prefer secure defaults
- prefer idempotent scripts
- prefer small, reviewable changes
- avoid hidden state and surprising side effects
- keep comments practical and high-signal
- keep documentation aligned with actual script behavior

For shell automation:

- write for OpenBSD userland where the code is intended to run there
- be explicit about any Linux-only or workstation-only tooling
- document assumptions about privileges, filesystem paths, and dependencies

## Documentation Changes

Documentation is a first-class contribution.

When changing docs:

- keep install paths concise and ordered
- separate quickstart guidance from advanced operations
- state when a step is optional
- state when a component is provider-specific
- keep the DR boundary clear: public integration surface here, private DR backend elsewhere

## Testing Expectations

Contributors should test as much as practical for the kind of change being made.

Examples:

- syntax checks for Python, PHP, and shell where possible
- dry-run execution for installer and phase tooling
- QEMU or lab validation for install, verify, and upgrade paths
- documentation walkthrough validation for onboarding changes

If something cannot be tested locally, say so clearly in the pull request.

## Pull Request Guidance

A good pull request should include:

- a short summary of the change
- why the change is needed
- affected components
- testing performed
- any remaining risks, follow-up work, or deployment notes

Smaller pull requests are easier to review and safer to merge.

## Commit and Review Quality

Aim for changes that are:

- minimal
- understandable
- reversible
- documented

If a change affects installation, verification, or recovery behavior, update the relevant docs in the same pull request.

## Version Target

The active public baseline is OpenBSD `7.8`. Contributions should target that baseline unless a change is explicitly about future-version preparation or documented compatibility work.

## Questions and Proposals

If you are unsure whether something belongs in the public repo, open a discussion or issue describing:

- the problem
- the proposed change
- whether it affects public automation, private DR workflows, or both

That is especially helpful for changes around:

- recovery integration
- optional third-party providers
- secrets handling
- supported deployment topology


## Issues and validation reports

Use the repository issue templates when reporting problems or validation results:
- **Bug report** for reproducible script, template, or runtime issues
- **Documentation gap** for stale or missing guidance
- **Operator validation report** for public-only readiness checks, QEMU runs, deployment tests, or restore drills

Never include secrets, private keys, API tokens, mailbox contents, or sensitive host data in an issue. Use the security policy for anything that could materially weaken a live deployment.
