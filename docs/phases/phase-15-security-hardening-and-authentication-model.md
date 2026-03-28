# Phase 15, security hardening and authentication model

## Purpose

Extend the public mail stack with:

- authentication policy baseline
- staged second-factor planning
- compatibility-aware hardening guidance

## Inputs

- MAIL_HOSTNAME
- ADMIN_EMAIL
- ROUNDCUBE_ENABLED
- WEB_VPN_ONLY

## Outputs

- auth policy example
- password policy example
- second-factor roadmap
- Dovecot hardening notes
- Roundcube hardening notes
- phase summary

## Run

doas ./scripts/phases/phase-15-apply.ksh

Verify:

./scripts/phases/phase-15-verify.ksh
