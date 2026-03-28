# Off-host replication and restore testing

## Purpose

This phase extends the public backup model with:

- off-host replication guidance
- backup transport safety notes
- restore test workflow
- verification checkpoints after restore drills

This remains operator-controlled and non-destructive by default.

## Why this matters

A backup is not enough if it only exists on the same host, and a restore plan is
not enough if it has never been tested.

This phase prepares the public project for:

- off-host copy planning
- transfer verification
- repeatable restore drills
- confidence testing before incidents occur

## Public baseline

Recommended pattern:

- local backup creation first
- integrity verification second
- encrypted or signed artifact copy off-host
- regular restore drill on a non-production target

## Off-host replication model

Use a conservative model such as:

- `scp`
- `rsync` over SSH
- removable encrypted media
- object storage, only if separately documented and verified

The public repo baseline prefers:

- SSH-based transfer
- operator-triggered replication
- checksum or signature verification after copy

## Restore testing model

Recommended order:

1. prepare clean test host or VM
2. verify backup signature and checksum
3. inspect manifest
4. restore config
5. restore TLS material
6. restore database
7. restore mail storage
8. start services
9. perform functional validation

## Functional validation examples

After a restore drill:

- verify `rcctl check` for relevant services
- verify IMAP login
- verify SMTP submission
- verify local mail delivery
- verify webmail access from the trusted path
- verify representative DNS assumptions used by the stack

## Outputs in this phase

This phase generates example artifacts for:

- off-host replication workflow
- restore drill checklist
- post-restore verification checklist
- replication and restore summary

## Next step

After this phase, the project is ready for deeper monitoring, reporting, and
optional public polish work.
