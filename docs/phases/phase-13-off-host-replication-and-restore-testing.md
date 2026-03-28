# Phase 13, off-host replication and restore testing

## Purpose

Extend the backup and DR baseline with:

- off-host replication guidance
- restore drill workflow
- verification after restore

## Inputs

- MAIL_HOSTNAME
- ALERT_EMAIL
- OPS_RETENTION_DAYS

## Outputs

- off-host replication example
- restore drill checklist
- post-restore validation checklist
- phase summary

## Run

doas ./scripts/phases/phase-13-apply.ksh

Verify:

./scripts/phases/phase-13-verify.ksh
