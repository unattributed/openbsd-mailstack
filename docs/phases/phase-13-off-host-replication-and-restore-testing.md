# Phase 13, off-host replication and restore testing

## Purpose

Extend the Phase 11 and 12 baseline with off-host copy planning, restore drills, and QEMU rehearsal.

## Inputs

- `BACKUP_OFFSITE_MODE`
- `BACKUP_OFFSITE_TARGET`
- `DR_SITE_SERVER_NAME`

## Outputs

- generated off-host replication summary
- generated restore drill summary
- generated post-restore validation checklist
- QEMU restore drill runner under `maint/qemu/`

## Run

```sh
doas ./scripts/phases/phase-13-apply.ksh
```

Verify:

```sh
./scripts/phases/phase-13-verify.ksh
```

## Refinement

Phase 13 can now be exercised from the unified backup runner and the DR host
bootstrap workflow, not only from individual backup scripts.
