# Backup and restore drill sequence

## Purpose

This document gives a public-safe sequence for producing, validating, replicating, and rehearsing restores for the mail stack.

## Recommended order

1. install the backup and DR helpers
2. run config, MariaDB, and mailstack backups
3. verify each resulting backup set
4. optionally replicate off-host
5. perform a staged restore drill
6. repeat the drill in QEMU before production use

## Commands

Install helpers:

```sh
doas ksh scripts/install/install-backup-dr-assets.ksh --apply
```

Create backups:

```sh
doas ksh scripts/ops/backup-config.ksh --run
doas ksh scripts/ops/backup-mariadb.ksh --run
doas ksh scripts/ops/backup-mailstack.ksh --run
```

Verify a backup set:

```sh
doas ksh scripts/ops/verify-backup-set.ksh --run-dir /var/backups/openbsd-mailstack/mailstack/latest
```

Replicate off-host:

```sh
doas ksh scripts/ops/replicate-backup-offhost.ksh   --dry-run   --run-dir /var/backups/openbsd-mailstack/mailstack/latest
```

Run a staged restore drill:

```sh
doas ksh scripts/ops/run-restore-drill.ksh   --archive /var/backups/openbsd-mailstack/mailstack/latest/mailstack-<timestamp>.tgz   --sha256 /var/backups/openbsd-mailstack/mailstack/latest/mailstack-<timestamp>.sha256
```

QEMU rehearsal:

```sh
ksh maint/qemu/lab-dr-restore-runner.ksh   --archive /path/to/mailstack-backup.tgz   --sha256 /path/to/mailstack-backup.sha256
```

## Unified Backup Run

A single public-safe runner now exists for the common path:

```sh
doas ksh scripts/ops/backup-all.ksh --dry-run
doas ksh scripts/ops/backup-all.ksh --run
```

That runner can optionally protect archives and replicate the mailstack backup
when those features are enabled in operator inputs.
