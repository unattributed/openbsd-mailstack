# 15. DR Host Bootstrap

This step adds the missing public-safe bootstrap path for a standby DR host.

## Goal

Prepare a clean OpenBSD host so it has the expected backup, restore, runtime,
and DR portal directories before the first restore rehearsal or production failover.

## Operator Inputs

Use ignored input files such as:

- `config/local/dr-host.conf`
- `/root/.config/openbsd-mailstack/dr-host.conf`
- `/root/.config/openbsd-mailstack/dr-site.conf`

Tracked examples:

- `config/dr-host.conf.example`
- `config/dr-site.conf.example`

## Dry Run

```sh
doas ksh scripts/install/provision-dr-site-host.ksh --dry-run
```

## Apply

```sh
doas ksh scripts/install/provision-dr-site-host.ksh --apply
```

## What It Does

- creates the DR host base root
- creates restore, backup, runtime, and log roots
- optionally installs the DR portal assets
- optionally patches nginx if the operator explicitly enables that behavior
- writes a bootstrap report under the runtime root when enabled

## Default Layout

- `/srv/openbsd-mailstack-dr`
- `/srv/openbsd-mailstack-dr/staging`
- `/srv/openbsd-mailstack-dr/releases`
- `/var/restore/openbsd-mailstack`
- `/var/backups/openbsd-mailstack`
- `/var/lib/openbsd-mailstack-dr`
- `/var/log/openbsd-mailstack-dr`

## Recommended Sequence

1. configure `dr-host.conf` and `dr-site.conf`
2. run the dry run and review the output
3. apply the bootstrap on the standby host
4. run `scripts/install/install-backup-schedule-assets.ksh --dry-run`
5. run a staged restore drill before any live failover
