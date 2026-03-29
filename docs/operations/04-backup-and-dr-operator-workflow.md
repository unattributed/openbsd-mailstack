# Backup and DR operator workflow

## Daily checks

- confirm the latest backup run directory exists
- confirm the latest `.sha256` file exists
- confirm the DR site still renders from an allowed address

## Weekly checks

- run `scripts/ops/verify-backup-set.ksh` against the latest mailstack backup
- run an off-host replication dry-run if the target changes often
- refresh the DR site content if runbooks or contacts changed

## Periodic drills

- perform a staged restore drill on the host
- perform a QEMU restore rehearsal before major platform changes
- document the result and any gaps discovered during the drill

## Daily Backup and DR Command Set

- `doas ksh scripts/ops/backup-all.ksh --run`
- `doas ksh scripts/ops/protect-backup-set.ksh --run --run-dir <run-dir>`
- `doas ksh scripts/ops/run-restore-drill.ksh --archive <archive> --sha256 <sha-file>`
- `doas ksh scripts/install/provision-dr-site-host.ksh --dry-run`
