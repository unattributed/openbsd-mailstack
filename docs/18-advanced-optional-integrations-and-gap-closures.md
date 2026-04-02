# Advanced optional integrations and gap closures

## Purpose

This phase closes the highest-value remaining public-safe gaps from the private repo without pretending that every late private behavior can or should be published.

It focuses on:

- a public-safe Suricata IDS baseline
- an optional Brevo webhook listener
- an optional SOGo baseline
- SBOM and host inventory workflows
- explicit documentation for anything that still must remain private or operator-specific

## What is materially usable now

A new operator can now use the public repo to:

- render a Suricata IDS baseline for OpenBSD
- stage helper scripts for Suricata dashboard export and PF candidate generation
- stage an optional Brevo webhook listener behind nginx, under the same control-plane allow wrapper used by the monitoring surface
- stage an optional SOGo baseline behind nginx, under the same control-plane allow wrapper used by the monitoring surface
- generate a public-safe source SBOM and host inventory, then run fallback or mapped vulnerability scans

## What remains optional or private

The public repo still does not publish:

- live Suricata captures, live eve.json content, or live PF table feeds
- live Brevo webhook endpoints or provider credentials
- live SOGo database contents or production identities
- private SBOM exception ownership data, live production inventories, or confidential scanning results

## Main public outputs

- `services/suricata/`
- `services/brevo/`
- `services/sogo/`
- `services/sbom/`
- `scripts/install/render-advanced-gap-configs.ksh`
- `scripts/install/install-advanced-gap-assets.ksh`
- `scripts/verify/verify-advanced-gap-assets.ksh`
- `scripts/phases/phase-17-apply.ksh`
- `scripts/phases/phase-17-verify.ksh`

## Recommended usage

1. review the new tracked example files under `config/`
2. place real optional values in ignored local inputs if you plan to enable them
3. run `scripts/phases/phase-17-apply.ksh`
4. review the staged optional asset trees under `.work/advanced/rootfs/` and `.work/advanced/sbom/`, keeping in mind that the live core runtime tree remains `.work/runtime/rootfs/`
5. review the live Phase 17 plan pack under `.work/advanced/phase-17/` and write the advanced readiness report under `.work/advanced/readiness/`
6. install optional assets only where they fit your deployment model
