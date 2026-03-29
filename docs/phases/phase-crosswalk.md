# Phase Crosswalk and Private-to-Public Migration Matrix

## Purpose

This document maps the private phase structure to the public phase structure and records the current migration state honestly.

The private source of truth for this comparison is the uploaded `openbsd-self-hosting-main.zip` archive, especially the `mail-phases/mail-phases-refit-7.8/` tree.

## Phase crosswalk

| Private source phase | Private scope summary | Public target phase or docs | Current public state |
|---|---|---|---|
| Phase 00, foundation | base host prep, packages, PF baseline, repo sync, restore staging | `docs/phases/phase-00-foundation.md`, `scripts/phases/phase-00-*` | Partial. Public phase establishes config and baseline validation, but not private restore staging or repo-sync behavior. |
| Phase 01, initial network, VPN, and TLS | WireGuard, PF integration, ACME, hostname pinning | `phase-01-network-and-external-access`, `phase-06-tls-and-certificate-automation` | Partial. Public network planning and TLS are split apart and more generic. |
| Phase 02, MariaDB secure baseline | local MariaDB hardening and database prep | `phase-02-mariadb-baseline` | Partial. Public docs and scripts exist, but service templates are not yet published. |
| Phase 03, PostfixAdmin and SQL wiring | PostfixAdmin deployment and schema wiring | `phase-03-postfixadmin-and-sql-wiring` | Improved in Phase 02. Public-safe templates, render helpers, and install helpers now exist for the core runtime, but deeper private operational depth still remains to migrate. |
| Phase 04, Postfix core and SQL integration | Postfix runtime, SQL maps, submission policy | `phase-04-postfix-core-and-sql-integration` | Partial. Public phase exists, service tree parity does not. |
| Phase 05, Dovecot auth, LMTP, and SASL | Dovecot runtime and mailbox delivery | `phase-05-dovecot-auth-and-mailbox-delivery` | Partial. Public phase exists, sanitized runtime configs remain to be published. |
| Phase 06, Rspamd filtering and Brevo relay | filtering, milter, relay posture | `phase-07-filtering-and-anti-abuse`, install docs for Brevo | Partial. Public scope is broader and more generic. |
| Phase 07, PostfixAdmin web and Roundcube | web plane exposure and webmail | `phase-08-webmail-and-admin-access` | Partial. Public VPN-only web model exists, but service parity is incomplete. |
| Phase 08, DNS, SPF, DKIM, DMARC, MX | domain publishing and identity records | `phase-09-dns-and-identity-publishing` | Partial. Public generated record examples exist. |
| Phase 09, Suricata integration | IDS integration and security telemetry | No direct parity phase yet, partly adjacent to `phase-15-security-hardening-and-authentication-model` | Not yet public at parity. |
| Phase 10, monitoring, logging, pfstat, backup | operational monitoring and reporting | `phase-10-operations-and-resilience`, `phase-14-monitoring-and-reporting-baseline` | Improved in Phase 05. Public-safe monitoring inputs, static monitoring pages, log summaries, reports, and install helpers now exist, but private dashboards and control-plane depth still remain out of scope. |
| Phase 11, disaster recovery integration | DR staging and recovery integration | `phase-11-backup-and-disaster-recovery`, `phase-12-advanced-backup-security-and-integrity`, `phase-13-off-host-replication-and-restore-testing` | Partial. Public docs exist, private implementation details remain out of scope. |
| Phase 12, maintenance, upgrades, regression, hardening | maintenance doctrine and upgrade hygiene | `phase-10-operations-and-resilience`, maintenance install and operations docs, selected `maint/` tooling | Improved in Phase 06. Public-safe maintenance inputs, upgrade wrappers, regression checks, rollback guidance, and a QEMU rehearsal path now exist, but private governance depth and control-plane automation remain out of scope. |
| Phase 13, SOGo calendar and CalDAV | groupware layer | Mentioned in `README.md` only | Not yet public as a reconciled phase. |
| Phase 14, semi-autonomous ops control plane | policy-gated automation and control plane | partially adjacent to `phase-14`, `phase-15`, `phase-16` | Not yet public at parity. |
| Upgrade tree phase 15, OpenBSD 7.8 release upgrade | upgrade-only workflow | no direct public parity phase | Intentionally outside current public phase set. |

## Migration matrix by private area

| Private area | Best public destination | Boundary type | Migration note |
|---|---|---|---|
| `postfix/`, `dovecot/`, `nginx/`, `rspamd/`, `redis/` | `services/` plus phase docs | sanitize and publish later | Good next-wave candidates. |
| `firewall/`, `wg/`, `dns/`, `ddns/` | `services/`, `scripts/`, `docs/` | sanitize and publish later | Must remove live bindings, domains, and IPs. |
| `mail-diagnostics/`, `monitoring/`, `backup-ops/`, `sbom/` | `scripts/`, `services/`, `maint/`, and `docs/operations/` | sanitize and publish incrementally | Backup and monitoring baselines are now public-safe; deeper private telemetry and SBOM material still remain to migrate. |
| `evidence/` | none | private only | Live host evidence should not be published. |
| `mail-phases/` refit and upgrade trees | `docs/phases/`, `scripts/phases/`, `maint/` | selective migration | Public phases should stay coherent even if numbering differs. |
| `suricata/` | `services/` plus security docs | sanitize and publish later | Needs generic rules and host-neutral references. |
| `sogo/` | `services/sogo/`, future phase docs | sanitize and publish later | Public mention exists, reconciled implementation does not. |
| runtime-specific secrets and credentials | none | private only | Replace with docs, examples, and ignored local inputs only. |

## Crosswalk rules for later phases

Use these rules for later reconciliation work:

1. preserve functional intent, not exact directory symmetry
2. split private phases when the public repo benefits from clearer separation
3. keep private-only items private only when they truly cannot be published safely
4. prefer sanitized runnable public-safe implementation over documentation-only stubs
5. mark partial parity explicitly until service configs, scripts, and docs line up

## Current planning takeaway

The public repo already has a strong framework, but the next major parity gains will come from publishing sanitized service trees and generic operations tooling, not from adding more placeholder phase headings.
