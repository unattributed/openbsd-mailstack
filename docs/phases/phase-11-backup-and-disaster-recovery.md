# Phase 11, backup and disaster recovery

## Purpose

Create a usable public backup and DR baseline.

## Inputs required

- `MAIL_HOSTNAME`
- `BACKUP_ROOT`
- `BACKUP_RETENTION_DAYS`
- `BACKUP_CONFIG_PATHS`
- `BACKUP_MAIL_PATHS`
- `BACKUP_RUNTIME_PATHS`
- `BACKUP_DATABASES`
- `RESTORE_STAGING_DIR`
- `DR_SITE_ENABLED`
- `DR_SITE_SERVER_NAME`

## Outputs

- live backup and DR plan pack under `.work/backup-dr/phase-11/`
- reusable backup, restore, and install helpers in `scripts/`
- readiness reporting through `scripts/ops/backup-dr-readiness-report.ksh`

## Run

```sh
doas ./scripts/phases/phase-11-apply.ksh
```

Verify:

```sh
./scripts/phases/phase-11-verify.ksh
```

Readiness report:

```sh
./scripts/ops/backup-dr-readiness-report.ksh --write
```

## Refinement

Phase 11 now writes a live plan pack into a gitignored work root instead of tracked repo guidance files. It also includes a public-safe standby host bootstrap path through `scripts/install/provision-dr-site-host.ksh`, in addition to the DR portal asset installer.
