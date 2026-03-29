# Off-host replication and restore testing

## Purpose

This phase turns the public backup baseline into a repeatable restore confidence path.

It adds:

- off-host replication helpers
- a staged restore drill helper
- a QEMU restore drill runner
- DR site provisioning guidance for a standby or DR-oriented control plane

## Off-host replication

Use the replication helper against a specific backup run:

```sh
doas ksh scripts/ops/replicate-backup-offhost.ksh   --dry-run   --run-dir /var/backups/openbsd-mailstack/mailstack/latest
```

Then switch to `--apply` once the remote target, SSH key, and path are confirmed.

## Restore drills

A public restore drill should use staged extraction first:

```sh
doas ksh scripts/ops/run-restore-drill.ksh   --archive /var/backups/openbsd-mailstack/mailstack/latest/mailstack-<timestamp>.tgz   --sha256 /var/backups/openbsd-mailstack/mailstack/latest/mailstack-<timestamp>.sha256
```

## QEMU-first restore rehearsal

Use the host-side QEMU runner once the VM lab is already bootstrapped and reachable:

```sh
ksh maint/qemu/lab-dr-restore-runner.ksh   --archive /path/to/mailstack-backup.tgz   --sha256 /path/to/mailstack-backup.sha256
```

That keeps restore testing inside the public repo and avoids assuming private-only recovery repositories.

## DR site as part of the DR path

The DR site is a separate but related surface. It gives operators a stable internal portal for:

- recovery scope
- staged restore commands
- contact points
- the restore sequence

That content is rendered from `maint/dr-site/` and provisioned by `scripts/install/install-dr-site-assets.ksh`.
