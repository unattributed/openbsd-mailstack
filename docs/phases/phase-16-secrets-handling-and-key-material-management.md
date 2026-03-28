# Phase 16, secrets handling and key material management

## Purpose

Extend the public mail stack with:

- secret classification guidance
- key material handling baseline
- rotation and storage notes

## Inputs

- MAIL_HOSTNAME
- ADMIN_EMAIL
- ALERT_EMAIL

## Outputs

- secret inventory example
- key inventory example
- rotation checklist
- secure storage notes
- phase summary

## Run

doas ./scripts/phases/phase-16-apply.ksh

Verify:

./scripts/phases/phase-16-verify.ksh
