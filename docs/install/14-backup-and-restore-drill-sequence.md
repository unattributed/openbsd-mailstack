# Backup and restore drill sequence

## Purpose

This document gives a public-safe sequence for producing, validating, replicating, and rehearsing restores for the mail stack.

## Recommended order

1. install the backup and DR helpers
2. generate the live backup and DR plan packs
3. write the readiness report
4. run config, MariaDB, and mailstack backups
5. verify each resulting backup set
6. optionally replicate off-host
7. perform a staged restore drill
8. repeat the drill in QEMU before production use

## Commands

Install helpers:

```sh
doas ksh scripts/install/install-backup-dr-assets.ksh --apply
```

Generate the phase plan packs:

```sh
OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-11-apply.ksh
OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-12-apply.ksh
OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-13-apply.ksh
```

Write the readiness report:

```sh
./scripts/ops/backup-dr-readiness-report.ksh --write
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

## Notes

The current repo now treats backup and DR planning as live operator workspace output under `.work/backup-dr/`, not as tracked publishable generated guidance.
