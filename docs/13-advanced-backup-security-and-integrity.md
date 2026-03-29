# Advanced backup security and integrity

## Purpose

This phase extends the baseline backup workflows with integrity and restore safety controls.

## Public-safe integrity layer

Every backup helper writes:

- a compressed archive
- a `manifest.txt`
- a `.sha256` file
- a short `summary.txt`

That means an operator can validate archive integrity before any restore attempt.

## Verification

Use the included helper:

```sh
doas ksh scripts/ops/verify-backup-set.ksh --run-dir /var/backups/openbsd-mailstack/mailstack/latest
```

## Optional signing and encryption

The public repo supports operator-supplied signing and encryption settings through `config/backup.conf`.

Supported public-safe patterns:

- `BACKUP_ENABLE_SIGNIFY=yes` with `BACKUP_SIGNIFY_SECRET_KEY`
- `BACKUP_ENABLE_GPG=yes` with `BACKUP_GPG_RECIPIENT`

Those settings are not committed. They belong in ignored files such as `config/backup.conf` or `/root/.config/openbsd-mailstack/backup.conf`.

## Restore safety defaults

The restore path is designed to be cautious.

Default behavior:

- verify the archive first
- extract into a staging directory
- stop before changing live files

Live overwrite only happens when the operator chooses it explicitly.

## Why the split matters

The private repo has host-specific DR detail that cannot be published safely. The public repo therefore focuses on a reliable, operator-driven baseline that can be adapted to different hosts without leaking private paths or credentials.
