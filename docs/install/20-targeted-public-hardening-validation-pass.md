# Targeted Public Hardening Validation Pass

This validation pass is intentionally narrow.

It is the repo-safe validation entrypoint for the current public hardening and runtime-secret surface, not a full end-to-end validation of every public phase.

Use it after applying public cleanup, hardening, or runtime-secret changes, especially around:

- phase 15 hardening artifacts
- phase 16 runtime-secret layout artifacts
- public repo readiness and publishable-content checks
- repo-side semantic integrity checks for the current public surface

## Validation flow

From the repo root:

```sh
./scripts/phases/phase-15-apply.ksh
./scripts/phases/phase-15-verify.ksh
./scripts/phases/phase-16-apply.ksh
./scripts/phases/phase-16-verify.ksh
./maint/validate-public-hardening-surface.ksh
```

## What this validates

This targeted pass currently checks for:

- missing phase 15 public-safe hardening assets
- missing phase 16 runtime-secret layout assets
- private hostname references in publishable content
- tracked operator input files that should remain untracked
- malformed generated examples caught by the public readiness checks
- repo secret guard failures
- repo-side shell and Python syntax checks when local validators are available
- unresolved placeholders in concrete generated examples
- phase apply and verify script coverage through Phase 17

## What this does not claim

This pass does not by itself prove:

- a full phase 00 through 17 deployment
- a complete host-side runtime validation
- end-to-end mail flow correctness
- backup and disaster-recovery execution success
- optional layer correctness for Suricata, Brevo, SOGo, SBOM, or monitoring

Use the broader install, phase, post-install, QEMU, and operator workflow docs for those paths.

## Compatibility note

The old entrypoint:

```sh
./maint/final-public-validation-pass.ksh
```

still works as a compatibility wrapper, but the clearer entrypoint is:

```sh
./maint/validate-public-hardening-surface.ksh
```
