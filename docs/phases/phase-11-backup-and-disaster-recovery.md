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

- generated backup scope summary
- generated restore workflow summary
- generated DR site provisioning summary
- reusable backup, restore, and install helpers in `scripts/`

## Run

```sh
doas ./scripts/phases/phase-11-apply.ksh
```

Verify:

```sh
./scripts/phases/phase-11-verify.ksh
```
