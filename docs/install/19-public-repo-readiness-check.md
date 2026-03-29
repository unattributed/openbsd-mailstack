# Public Repo Readiness Check

This checklist confirms that a new operator can work from the public repo alone.

## A. Discovery path

A new operator should be able to discover:

- prerequisites and provider onboarding
- install order
- QEMU test path
- production deployment sequence
- backup and restore path
- monitoring and maintenance path
- security hardening and runtime secret layout path

## B. Core public-safe assets

The repo should contain tracked assets for:

- core mail runtime templates
- staged rendered examples
- backup and DR helpers
- monitoring and maintenance helpers
- PF, WireGuard, DNS, and DDNS helpers
- Suricata, Brevo, SOGo, and SBOM optional layers
- `doas` and SSH hardening helpers
- host-local runtime secret layout helpers

## C. Intentional boundaries

The following are still intentionally private:

- live production evidence
- encrypted DR payloads and restore archives
- real secrets, PATs, API tokens, and private keys
- site-specific control-plane doctrine

## D. Final operator reality

The public repo is considered ready when the remaining work is local operator
population of:

- domains and hostnames
- network and exposure values
- provider accounts and API keys
- host-local runtime secret files
- final hardening choices
