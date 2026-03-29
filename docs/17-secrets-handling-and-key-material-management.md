# Secrets handling and key material management

## Purpose

This phase now moves beyond inventory notes and publishes a reusable,
public-safe runtime secret layout model.

It covers:

- host-local runtime secret file layout
- tracked example secret-bearing files that remain safe to publish
- ownership and mode expectations
- guarded repo hygiene checks
- rotation guidance that maps to the public services already present

## What is now automated

The public repo now includes runnable helpers for:

- rendering host-local runtime secret stubs into a safe staging directory
- creating host-local secret directories
- verifying expected runtime secret paths if they exist
- checking the tracked repo for secret hygiene regressions

The main helpers are:

- `maint/runtime-secret-layout.ksh`
- `maint/repo-secret-guard.ksh`
- `scripts/phases/phase-16-apply.ksh`
- `scripts/phases/phase-16-verify.ksh`

## Public-safe runtime secret model

Tracked files contain examples only.
Live values stay outside git.

The public-safe baseline uses these classes:

### Service credentials

Examples:

- PostfixAdmin database credentials
- SOGo database credentials
- API credentials such as VirusTotal

### Runtime PHP secret files

Examples:

- `/etc/postfixadmin/secrets.php`
- `/etc/roundcube/secrets.inc.php`

### Operational recovery credentials

Examples:

- DR env files
- off-host restore credentials
- PATs used by operator-controlled automation

## Inputs

This phase uses values from:

- `config/secrets-runtime.conf.example`
- `config/secrets.conf.example`
- `config/system.conf.example`

## Outputs

Phase 16 now renders public-safe examples under:

- `services/generated/rootfs/etc/postfixadmin/secrets.php.example`
- `services/generated/rootfs/etc/roundcube/secrets.inc.php.example`
- `services/generated/rootfs/etc/examples/openbsd-mailstack/postfixadmin-db.env`
- `services/generated/rootfs/etc/examples/openbsd-mailstack/sogo-db.env`
- `services/generated/rootfs/etc/examples/openbsd-mailstack/runtime-secret-paths.txt`
- `services/generated/rootfs/etc/examples/openbsd-mailstack/runtime-secret-permissions.txt`
- `services/generated/rootfs/etc/examples/openbsd-mailstack/rotation-checklist.txt`

## What remains intentionally private

This phase still does not publish:

- real passwords, PATs, API tokens, or SMTP credentials
- real TLS, DKIM, or WireGuard private keys
- encrypted restore payloads
- production mailbox archives or database dumps
- live site-specific recovery credentials

That boundary is intentional. The public repo now provides the layout and the
checks, while operators provide the real secret material locally.
