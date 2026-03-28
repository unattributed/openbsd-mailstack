# Advanced backup security and integrity

## Purpose

This phase extends the backup baseline with:

- encryption guidance
- integrity verification
- backup manifests
- restore verification workflow

This remains non-destructive and operator-controlled.

## Security model

- backups may contain secrets, encrypt them
- verify integrity before restore
- never trust a backup blindly

## Encryption (recommended)

Use OpenBSD base tools:

- tar
- gzip
- signify (preferred on OpenBSD)
- or GPG if already in use

Example (signify):

```sh
tar -czf backup.tgz /etc /var/vmail
signify -S -s /root/.signify/backup.sec -m backup.tgz
```

## Integrity verification

```sh
signify -V -p /root/.signify/backup.pub -m backup.tgz
```

## Manifest model

Generate a manifest for backup contents:

```sh
tar -tzf backup.tgz > backup.manifest
sha256 backup.tgz > backup.sha256
```

## Restore safety

Before restore:

- verify signature
- verify checksum
- inspect manifest

## Recommended flow

1. create backup
2. sign backup
3. generate checksum
4. store off-host
5. verify periodically
