# Project status

## Final public audit summary

The public repo now provides a materially usable public-safe operator baseline for OpenBSD mailstack deployment and operations. The final audit result is:

- **Yes**, a new user can discover prerequisites from `docs/install/README.md`
- **Yes**, a new user can discover install order from `docs/install/09-install-order-and-phase-sequence.md`
- **Yes**, a new user can discover the test and QEMU path from `docs/install/06-qemu-lab-and-vm-testing.md` and `docs/install/10-qemu-first-validation-path.md`
- **Yes**, a new user can discover the operations path from `docs/operations/` and the later install docs
- **Yes**, a new user can discover the backup path from `docs/12-backup-and-disaster-recovery.md` and `docs/install/14-backup-and-restore-drill-sequence.md`
- **Yes**, a new user can discover the recovery and DR path from `docs/install/13-dr-site-provisioning.md`, `docs/install/15-dr-host-bootstrap.md`, and `docs/14-off-host-replication-and-restore-testing.md`
- **Yes**, QEMU and autonomous installer materials are present as public features under `maint/qemu/` and `maint/openbsd-autonomous-installer/`

## Current public-safe scope

The public repo now contains public-safe material for:

- operator input handling and phase orchestration
- core mail runtime templates and staged rendered assets
- QEMU lab and autonomous installer workflows
- backup, DR portal, DR host bootstrap, restore drill, and off-host replication helpers
- monitoring, diagnostics, reporting, and log-management helpers
- maintenance, upgrades, regression, and rollback planning helpers
- PF, WireGuard, DNS, and Vultr DDNS templates and helpers
- optional Suricata, Brevo webhook, SOGo, and SBOM workflows

## Private source areas and current public disposition

| Private source area | Public disposition |
|---|---|
| `mariadb`, `postfixadmin`, `postfix`, `dovecot`, `nginx`, `roundcubemail`, `rspamd`, `redis`, `clamd`, `freshclam` | materially migrated into `services/`, `scripts/install/`, and `scripts/verify/` |
| `firewall`, `wg`, `dns`, `ddns` | materially migrated into public-safe templates, renderers, and verification helpers |
| `backup-ops` | materially migrated into backup, restore, DR, and drill workflows |
| `monitoring`, `mail-diagnostics`, `system`, `utilities` | materially absorbed into `scripts/ops/`, `scripts/verify/`, `maint/`, and docs |
| `suricata`, `brevo`, `sogo`, `sbom` | published as optional public-safe advanced layers |
| `evidence` | intentionally private |
| `deprecated` | intentionally not migrated |
| host-specific control-plane policy and live inventories | intentionally private or only partially generalized |

## Exact remaining gaps

The remaining public gaps are now specific:

1. Phase 15, security hardening, remains more documentation-led than automation-led.
2. Phase 16, secrets handling and key material management, remains more documentation-led than automation-led.
3. Live production evidence, incident artifacts, mailbox data, restore payloads, and provider credentials remain intentionally private.
4. Site-specific control-plane automation and autonomous remediation policy are not generalized into this public repo.
5. Some optional integrations remain provider-bound by design, even where public-safe templates now exist.

## Cleanup completed in the final audit

The final audit cleaned up or added:

- stale completeness wording in top-level navigation docs
- a clearer prerequisites, install, test, operations, backup, and recovery discovery path
- a public repo readiness check doc and verifier
- removal of accidental Python cache artifacts from tracked service content
- service-level ignore rules to prevent future `__pycache__` and `*.pyc` commits

## Recommended next step

Use `docs/install/19-public-repo-readiness-check.md` and `scripts/verify/verify-public-repo-readiness.ksh` before treating the repo as your authoritative public operator baseline.
