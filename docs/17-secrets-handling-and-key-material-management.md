# Secrets handling and key material management

## Purpose

This phase extends the public `openbsd-mailstack` project with a secrets and key
material management baseline.

The focus is on:

- secret classification
- key material handling guidance
- storage boundary definition
- rotation planning
- public-safe handling patterns
- operator review artifacts

## Why this matters

A secure mail platform relies on secrets and keys that must be handled
deliberately.

This phase helps operators define:

- which values are secrets
- which files contain private key material
- what must never enter Git
- where encrypted storage should be preferred
- how rotation and review should be staged

## Public baseline

The public baseline for this phase is conservative:

- never commit live secrets
- never commit private keys
- keep example config separate from real secret values
- prefer encrypted storage for backup copies of key material
- document rotation and recovery before making changes
- use operator-reviewed workflows, not blind automation

## Secret classes

### Class 1, service credentials

Examples:

- MariaDB passwords
- PostfixAdmin database credentials
- Dovecot SQL credentials
- API keys

### Class 2, private key material

Examples:

- TLS private keys
- DKIM private keys
- signing keys used for backup verification

### Class 3, sensitive operational artifacts

Examples:

- backup encryption keys
- emergency recovery bundles
- off-host restore credentials

## Public-safe handling rules

- commit only `*.example` files or generated placeholders
- store live secrets outside Git
- encrypt backup copies of key material
- document ownership and permissions clearly
- review access to secret-bearing files regularly

## Rotation model

Recommended stages:

1. inventory the secret or key
2. identify dependencies
3. prepare replacement value or keypair
4. update service configuration
5. reload or restart service safely
6. verify functionality
7. revoke or remove old material
8. update backup and recovery references

## Outputs in this phase

This phase generates example artifacts for:

- secret inventory guidance
- key material inventory guidance
- rotation checklist
- secure storage notes
- phase summary

## Next step

After this phase, the project is ready for either a full documentation cleanup
pass or deeper policy work around compliance, auditability, and enforcement.
