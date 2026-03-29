# Public Repo Readiness Check

This checklist confirms that a new operator can work from the public repository alone, without needing private repo material for the public-safe baseline.

## A. Discovery path

A new operator should be able to discover:

- prerequisites and provider onboarding
- local operator input layout
- install order
- QEMU validation path
- production deployment sequence
- backup and restore path
- monitoring and maintenance path
- security hardening and runtime secret layout path

The main navigation documents for that are:

- [README](../../README.md)
- [Documentation map](../README.md)
- [Install guide](README.md)
- [Phase crosswalk](../phases/phase-crosswalk.md)

## B. Core public-safe assets

The repository should contain tracked assets for:

- core mail runtime templates
- staged rendered examples
- backup and DR helpers
- monitoring and maintenance helpers
- PF, WireGuard, DNS, and DDNS helpers
- Suricata, Brevo, SOGo, and SBOM optional layers
- `doas` and SSH hardening helpers
- host-local runtime secret layout helpers

## C. Documentation consistency

The repository should also satisfy these documentation conditions:

- README and install docs describe the same operator path
- phase docs match the actual scripts and service assets present
- no document still implies private assets were published when they were not
- navigation documents point to the current public-safe baseline, not an earlier lighter state

## D. Intentional boundaries

The following are still intentionally private:

- live production evidence
- encrypted DR payloads and restore archives
- real secrets, PATs, API tokens, and private keys
- site-specific control-plane doctrine

## E. Final operator reality

The public repository is considered ready when the remaining work is local operator population of:

- domains and hostnames
- network and exposure values
- provider accounts and API keys
- host-local runtime secret files
- final hardening choices
