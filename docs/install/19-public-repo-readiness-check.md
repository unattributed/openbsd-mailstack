# Public repo readiness check

## Purpose

This document is the final operator-facing audit for the public repo. It answers a simple question:

Can a new operator discover prerequisites, install order, test path, operations path, backup path, and recovery path from the public repo alone?

## Audit answer

Yes, with the following navigation path:

- prerequisites, `docs/install/README.md`
- install order, `docs/install/09-install-order-and-phase-sequence.md`
- QEMU and validation path, `docs/install/06-qemu-lab-and-vm-testing.md` and `docs/install/10-qemu-first-validation-path.md`
- first production deployment, `docs/install/11-first-production-deployment-sequence.md`
- post-install checks, `docs/install/12-post-install-checks.md`
- backup and restore drill path, `docs/install/14-backup-and-restore-drill-sequence.md`
- DR site and DR host path, `docs/install/13-dr-site-provisioning.md` and `docs/install/15-dr-host-bootstrap.md`
- operations, monitoring, and maintenance, `docs/operations/` plus `docs/install/16-monitoring-diagnostics-and-reporting.md` and `docs/install/17-maintenance-upgrades-regression-and-rollback.md`
- optional advanced integrations, `docs/install/18-advanced-optional-integrations-and-gap-closures.md`

## What this audit checked

This final audit checked:

- the top-level navigation docs point to real files that exist
- the public phase docs still match the apply and verify scripts that exist
- the repo no longer carries accidental Python cache artifacts in tracked service content
- QEMU and autonomous installer features are still represented as public features
- remaining gaps are described explicitly rather than hidden behind vague parity language

## Recommended verification command

Run the public readiness verifier from the repo root:

```sh
./scripts/verify/verify-public-repo-readiness.ksh
```

## Exact remaining gaps

The public repo is coherent, but it still does not include:

- live production secrets, keys, evidence, or restore payloads
- site-specific control-plane policy that cannot be generalized safely
- deeper automation for phases 15 and 16 beyond the published docs and baseline helpers

Those are deliberate boundaries, not accidental omissions.


## Follow-up correction pass

After the initial readiness audit, a final public-only correction pass removed the remaining Roundcube hostname leak and cleaned malformed staged generated files. The follow-up validation command is:

```sh
./maint/final-public-validation-pass.ksh
```
