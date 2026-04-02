# Project Status

## Current public completeness

The public repository now provides a materially usable public-safe baseline for:

- phase foundation and operator input handling
- phase 02 through 08 now include phase-scoped summaries and targeted verify coverage on top of the shared core runtime renderer
- core mail runtime rendering and staged example output
- install order, QEMU validation, and first production deployment guidance
- backup, disaster recovery, restore drills, DR site assets, and DR host bootstrap
- monitoring, diagnostics, reporting, visibility helpers, and the richer static `/_ops/monitor/` site path
- maintenance, upgrade, regression, and rollback helpers
- PF, WireGuard, DNS, and Vultr DDNS baseline assets
- optional Suricata, Brevo, SOGo, and SBOM layers
- security hardening and authentication helpers for `doas` and SSH
- host-local runtime secret layout and repo hygiene helpers

## What a new operator can do from the public repo alone

A new operator can now:

1. discover prerequisites and provider onboarding
2. populate local operator input files with their own values
3. render the core runtime and later optional layers
4. validate the build path in QEMU
5. apply and verify the phased deployment path on a real OpenBSD host
6. use backup, DR, monitoring, the richer `/_ops/monitor/` path, and maintenance workflows from the public repo
7. use the targeted public hardening validation pass to confirm the current publishable hardening surface is internally coherent

## What still depends on the operator

The operator still needs to provide:

- domain and hostname values
- network, exposure, and peer values
- provider accounts and API credentials
- host-local runtime secret files
- final hardening choices and deployment policy

That is the intended public operating model.

## Intentional boundaries

The remaining boundaries are specific and deliberate:

- live production evidence, restore archives, and site-specific control-plane doctrine remain private
- provider-specific integrations beyond the published public-safe set are not generalized here
- real secrets, private keys, recovery payloads, and live production data remain out of Git by design

## Documentation and validation anchors

The best summary documents are:

- [README](../README.md)
- [Documentation map](README.md)
- [Phase crosswalk](phases/phase-crosswalk.md)
- [Public repo readiness check](install/19-public-repo-readiness-check.md)
- [Targeted public hardening validation pass](install/20-targeted-public-hardening-validation-pass.md)
