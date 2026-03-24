# Security Policy

## Scope

`openbsd-mailstack` is a public infrastructure repository for a hardened OpenBSD mail platform. This policy covers vulnerabilities in the public codebase, including:

- installer and bootstrap tooling
- configuration templates
- phase automation and verification scripts
- monitoring, maintenance, and backup orchestration
- DR payload generation and public DR integration hooks

This policy does not cover private recovery backends, operator vaults, encrypted snapshot stores, or site-specific secrets that are intentionally kept outside this repository.

## Supported Versions

The supported public baseline is:

- OpenBSD `7.8`
- the current `main` branch

Security fixes should target the active public baseline first. Legacy internal trees, private recovery repositories, and superseded deployment artifacts are not part of the supported public surface unless explicitly stated otherwise.

## Reporting a Vulnerability

Do not open a public GitHub issue for a suspected security vulnerability.

Use one of these private channels instead:

1. GitHub Private Vulnerability Reporting for this repository, if enabled.
2. The project security contact published in the repository profile or organization security page.

Your report should include:

- a clear description of the issue
- affected component or file paths
- expected vs actual behavior
- impact assessment
- reproduction steps or proof of concept, if safe to share
- any relevant OpenBSD, package, or deployment context

## Sensitive Material

Do not include any live secrets in vulnerability reports, pull requests, issues, or examples.

This includes:

- private keys
- API tokens
- PATs
- real domains tied to active infrastructure
- customer or operator email addresses
- production IP addresses when not required for understanding the issue
- encrypted or plaintext recovery artifacts

Use placeholders and reserved domains such as `example.com`, `example.net`, and `example.org`.

## Expected Response

The project aims to:

- acknowledge valid reports promptly
- reproduce and triage issues
- coordinate remediation before public disclosure when appropriate
- credit reporters when they want attribution and when disclosure is safe

Response times depend on severity and maintainer availability. High-impact issues affecting authentication, privilege boundaries, exposed services, secret handling, or recovery workflows should be prioritized.

## Disclosure Guidance

Please allow maintainers reasonable time to investigate and prepare a fix before public disclosure.

If the issue has operational safety implications, maintainers may choose to:

- publish a fix before detailed write-up
- delay exploit details until affected users have a practical upgrade path
- ship documentation changes together with code changes when misconfiguration risk is part of the issue

## Repository Security Expectations

Contributors are expected to preserve these project boundaries:

- keep real secrets and recovery data out of the public repo
- keep tracked examples neutral and non-production
- keep domain topology configurable for both single-domain and multi-domain deployments
- keep public automation separate from private DR implementation details
- prefer secure defaults and explicit verification over implicit behavior

## Out of Scope for Public Disclosure Workflows

The following should be handled through private operational channels, not this public repo:

- active production incidents on private deployments
- recovery media contents
- encrypted snapshot repositories
- operator workstation compromise
- site-specific credentials or trust anchors
