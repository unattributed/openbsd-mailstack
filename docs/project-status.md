# Project Status

## Current public completeness

The public repo now contains a materially usable baseline for:

- phase 01 parity foundation and operator input handling
- core mail runtime templates and staged rendered assets
- install, QEMU validation, and operator workflow guidance
- backup, restore, DR portal, and DR host provisioning guidance
- monitoring, diagnostics, and reporting helpers
- maintenance, upgrade, regression, and rollback helpers
- network exposure, PF, WireGuard, DNS, and Vultr DDNS baseline assets
- advanced optional Suricata, Brevo, SOGo, and SBOM assets
- phase 15 security hardening and authentication helpers
- phase 16 runtime secret layout and repo hygiene helpers

## What was closed in this gap-closure pass

The public repo previously had two remaining core gaps that were real, not vague:

- Phase 15 was more documentation-led than automation-led
- Phase 16 was more documentation-led than automation-led

That is now reduced substantially.

The public repo now includes public-safe tooling for:

- broad baseline `doas` policy rendering and drift checks
- optional command-scoped `doas` transition with backup and rollback
- SSH hardening planning, apply, verify, and rollback
- SSH watchdog health checks
- host-local runtime secret directory layout planning
- host-local runtime secret stub rendering into safe staging locations
- repo secret hygiene checks that also guard against private hostname regression

## What remains intentionally unresolved

The remaining gaps are now specific boundaries rather than missing core migration work:

- live production evidence, restore archives, and site-specific control-plane doctrine remain intentionally private
- provider-specific integrations beyond the published public-safe set are not generalized here
- operators must still supply their own identities, secrets, private keys, and exposure policy locally

## Practical outcome

A new operator can now discover, render, review, validate, and maintain a public-safe mail stack baseline from the public repo alone.

The operator still needs to provide:

- domains and network values
- provider accounts and API credentials
- host-local runtime secret files
- exposure policy and final hardening choices

That is part of the public design, not an unclosed migration defect.
