# Phase 16, secrets handling and key material management

## Purpose

Extend the public mail stack with real public-safe runtime secret layout assets
for:

- host-local secret files
- PHP runtime secret examples
- database env file examples
- permissions and rotation guidance

## Inputs

- `config/secrets-runtime.conf.example`
- `config/secrets.conf.example`
- `config/system.conf.example`

## Outputs

- runtime secret path inventory
- runtime secret permissions inventory
- PostfixAdmin and Roundcube runtime secret examples
- host-local env file examples
- rotation checklist
- phase summary

## Main helpers

- `maint/runtime-secret-layout.ksh`
- `maint/repo-secret-guard.ksh`

## Run

```sh
./scripts/phases/phase-16-apply.ksh
```

Verify:

```sh
./scripts/phases/phase-16-verify.ksh
```
