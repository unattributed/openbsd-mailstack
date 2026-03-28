# Phase 12, advanced backup security and integrity

## Purpose

Extend Phase 11 with:

- encryption
- integrity checks
- manifest generation

## Inputs

- MAIL_HOSTNAME
- OPS_RETENTION_DAYS

## Outputs

- encrypted backup example
- checksum example
- manifest example
- verification workflow

## Run

doas ./scripts/phases/phase-12-apply.ksh

Verify:

./scripts/phases/phase-12-verify.ksh
