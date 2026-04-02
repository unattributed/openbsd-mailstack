# Phase Crosswalk

This document maps the public phase documents and scripts to the current public-safe implementation state.

## Public phase map

| Phase | State | Primary public assets |
|---|---|---|
| Phase 00, foundation | materially usable | foundation docs, shared input model, apply and verify scripts |
| Phase 01, network and external access | materially usable | PF, WireGuard, DNS, DDNS templates and helpers |
| Phase 02, MariaDB baseline | materially usable | MariaDB templates, shared core runtime rendering, and phase-scoped summary and verify coverage |
| Phase 03, PostfixAdmin and SQL wiring | materially usable | PostfixAdmin SQL wiring assets, shared core runtime rendering, and phase-scoped summary and verify coverage |
| Phase 04, Postfix core and SQL integration | materially usable | Postfix templates, SQL-backed mail routing assets, and phase-scoped summary and verify coverage |
| Phase 05, Dovecot auth and mailbox delivery | materially usable | Dovecot templates, mailbox delivery and auth wiring, and phase-scoped summary and verify coverage |
| Phase 06, TLS and certificate automation | materially usable | staged TLS-related config wiring, deployment guidance, and phase-scoped summary and verify coverage |
| Phase 07, filtering and anti-abuse | materially usable | Rspamd, ClamAV, anti-abuse helpers, and phase-scoped summary and verify coverage |
| Phase 08, webmail and admin access | materially usable | Roundcube, PostfixAdmin, nginx web-plane assets, and phase-scoped summary and verify coverage |
| Phase 09, DNS and identity publishing | materially usable | DNS publishing guidance and shared DNS input model |
| Phase 10, operations and resilience | materially usable | install, post-install, operator workflow, and resilience docs |
| Phase 11, backup and disaster recovery | materially usable | backup helpers, restore helpers, DR docs, and live plan packs |
| Phase 12, advanced backup security and integrity | materially usable | archive protection, verification, backup hygiene, and live integrity plan packs |
| Phase 13, off-host replication and restore testing | materially usable | off-host replication helpers, QEMU restore drill path, and live drill plan packs |
| Phase 14, monitoring and reporting baseline | materially usable | monitoring collectors, reporting helpers, nginx ops assets, newsyslog assets, and the richer static `/_ops/monitor/` site model |
| Phase 15, security hardening and authentication model | materially usable | `doas`, SSH hardening, and authentication policy helpers |
| Phase 16, secrets handling and key material management | materially usable | host-local runtime secret layout, repo hygiene, and verification helpers |
| Phase 17, advanced optional integrations and gap closures | materially usable | Suricata, Brevo, SOGo, SBOM, and late optional layers |

## How to use this map

- read the phase narrative in `docs/phases/`
- review the corresponding service templates and generated examples
- run the matching apply and verify scripts from `scripts/phases/`
- use the install and operations docs for the broader workflow around each phase

## Exact remaining gaps

The remaining gaps are intentional boundaries, not missing core migration work:

- live production evidence, recovery archives, and site-specific control-plane doctrine remain private
- provider-specific integrations beyond the published public-safe set are not generalized here
- operators still need to supply their own identities, secrets, private keys, and exposure policy

## Related documents

- [Project status](../project-status.md)
- [Documentation map](../README.md)
- [Install guide](../install/README.md)
- [Public repo readiness check](../install/19-public-repo-readiness-check.md)
- [OpenBSD native ops monitoring site](../install/22-openbsd-native-ops-monitoring-site.md)
