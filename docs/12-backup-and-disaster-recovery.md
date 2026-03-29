# Backup and disaster recovery

## Purpose

This phase moves the public repo from backup theory to a usable public-safe baseline.

It now includes:

- operator input files for backup and DR settings
- runnable backup helpers for config, MariaDB, and the broader mail stack
- a non-destructive restore path by default
- DR site provisioning assets and an installer

## Public backup model

The public baseline assumes three separate backup concerns:

1. configuration and TLS related material
2. MariaDB logical dumps
3. mailbox and broader runtime state

That split keeps restore planning explicit and lets an operator validate each layer independently.

## Core scripts

Install the helper scripts onto an OpenBSD target host:

```sh
cd /home/foo/Workspace/openbsd-mailstack
doas ksh scripts/install/install-backup-dr-assets.ksh --apply
```

Run backups:

```sh
doas ksh scripts/ops/backup-config.ksh --run
doas ksh scripts/ops/backup-mariadb.ksh --run
doas ksh scripts/ops/backup-mailstack.ksh --run
```

Verify a backup set:

```sh
doas ksh scripts/ops/verify-backup-set.ksh --run-dir /var/backups/openbsd-mailstack/mailstack/latest
```

## Restore model

The restore helper defaults to staged extraction only. This is deliberate.

```sh
doas ksh scripts/ops/restore-mailstack.ksh   --archive /var/backups/openbsd-mailstack/mailstack/latest/mailstack-<timestamp>.tgz   --sha256 /var/backups/openbsd-mailstack/mailstack/latest/mailstack-<timestamp>.sha256
```

That extracts the payload into `RESTORE_STAGING_DIR` and stops.

A direct file restore requires both of the following:

- explicit use of `--apply-files`
- `RESTORE_ALLOW_OVERWRITE=yes`

Database import is also explicit, via `--apply-database`.

## DR site provisioning

This phase also adds a public-safe DR site under `maint/dr-site/` and an installer:

```sh
doas ksh scripts/install/install-dr-site-assets.ksh --dry-run
doas ksh scripts/install/install-dr-site-assets.ksh --apply
```

The installer copies rendered static pages into the nginx publish root, renders an nginx location template, and can optionally patch the chosen nginx server config when `DR_SITE_PATCH_SERVER_CONF=yes`.

## What remains intentionally unresolved

The public repo does not publish private off-host repository state, encrypted production payloads, or live host evidence. Those remain operator-owned inputs and are documented as such.
