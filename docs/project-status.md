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
- advanced optional Suricata, Brevo webhook, SOGo, and SBOM assets

## What Phase 07 added

Phase 07 moved the public repo beyond planning-only network guidance. It now
includes:

- tracked `dns.conf.example` and `ddns.conf.example`
- staged PF, WireGuard, Unbound, and DDNS outputs
- render, install, verify, and report helpers for the network layer
- public-safe DDNS preview and optional live sync tooling

## What is still intentionally unresolved

The public repo still does not claim parity for:

- real production IPs, peer keys, and DNS zones
- private PF tables and evidence feeds
- live provider credentials or site-specific operational doctrine
- live Suricata evidence, private webhook endpoints, SOGo database contents, and production SBOM findings
