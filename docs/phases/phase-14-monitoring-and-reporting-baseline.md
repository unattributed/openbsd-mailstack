# Phase 14, monitoring and reporting baseline

## Purpose

Extend the public operations model with:

- service status review
- basic reporting guidance
- operational summary generation

## Inputs

- MAIL_HOSTNAME
- ALERT_EMAIL
- OPS_ENABLE_HEALTHCHECKS
- OPS_ENABLE_LOG_SUMMARY

## Outputs

- monitoring checklist
- service review script example
- daily report example
- monitoring summary

## Run

doas ./scripts/phases/phase-14-apply.ksh

Verify:

./scripts/phases/phase-14-verify.ksh
