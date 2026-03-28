# Phase 11, backup and disaster recovery

## Purpose

Establish a safe DR baseline.

## Inputs required

- MAIL_HOSTNAME
- OPS_RETENTION_DAYS

## Outputs

- backup scope file
- backup script example
- restore runbook
- DR summary

## Run

doas ./scripts/phases/phase-11-apply.ksh

Verify:

./scripts/phases/phase-11-verify.ksh
