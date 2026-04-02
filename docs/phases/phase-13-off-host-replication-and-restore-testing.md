# Phase 13, off-host replication and restore testing

## Purpose

Extend the Phase 11 and 12 baseline with off-host copy planning, restore drills, and QEMU rehearsal.

## Inputs

- `BACKUP_OFFSITE_MODE`
- `BACKUP_OFFSITE_TARGET`
- `DR_SITE_SERVER_NAME`

## Outputs

- live off-host and drill plan pack under `.work/backup-dr/phase-13/`
- post-restore validation checklist in the same gitignored work root
- QEMU restore drill runner under `maint/qemu/`
- readiness reporting through `scripts/ops/backup-dr-readiness-report.ksh`

## Run

```sh
doas ./scripts/phases/phase-13-apply.ksh
```

Verify:

```sh
./scripts/phases/phase-13-verify.ksh
```

## Refinement

Phase 13 can now be exercised from a unified backup and DR readiness surface, not only from individual backup scripts and tracked generated notes.
