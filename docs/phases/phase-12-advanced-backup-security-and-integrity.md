# Phase 12, advanced backup security and integrity

## Purpose

Extend the Phase 11 baseline with integrity and controlled restore behavior.

## Inputs

- `BACKUP_ENABLE_SIGNIFY`
- `BACKUP_SIGNIFY_SECRET_KEY`
- `BACKUP_ENABLE_GPG`
- `BACKUP_GPG_RECIPIENT`
- `BACKUP_MANIFEST_MODE`
- `RESTORE_ALLOW_OVERWRITE`

## Outputs

- live integrity plan pack under `.work/backup-dr/phase-12/`
- archive protection guidance tied to the actual helper scripts
- verification helper usage guidance

## Run

```sh
doas ./scripts/phases/phase-12-apply.ksh
```

Verify:

```sh
./scripts/phases/phase-12-verify.ksh
```

## Refinement

Phase 12 now writes a gitignored live plan pack instead of tracked generated guidance. It also keeps a concrete helper for archive protection:

- `scripts/ops/protect-backup-set.ksh`
