# Maintenance, upgrades, regression, and rollback baseline

## Purpose

This document explains the public-safe maintenance layer for `openbsd-mailstack`.
It turns later maintenance work from private doctrine into a reusable operator baseline.

## What this layer adds

- a tracked example for maintenance policy inputs
- public-safe wrappers for `syspatch` and `pkg_add -u`
- regression checks after host changes
- rollback-oriented guidance that starts from a recorded pre-change snapshot
- optional cron installation for weekly maintenance review
- a QEMU lab upgrade rehearsal path

## Default operating model

The public repo is intentionally conservative.

- maintenance starts with repo and operator-input checks
- the host state is captured before changes are made
- `syspatch` and `pkg_add -u -I` are run through repo-managed wrappers
- regression checks run after changes
- rollback guidance is printed instead of pretending package rollback is automatic on OpenBSD

## Key public-safe files

- `config/maintenance.conf.example`
- `scripts/ops/maintenance-run.ksh`
- `scripts/ops/maintenance-preflight.ksh`
- `scripts/ops/maintenance-regression.ksh`
- `scripts/ops/maintenance-rollback-plan.ksh`
- `scripts/install/install-maintenance-assets.ksh`
- `scripts/verify/verify-maintenance-assets.ksh`
- `maint/openbsd-syspatch.ksh`
- `maint/openbsd-pkg-upgrade.ksh`
- `maint/regression-test.ksh`
- `maint/rollback-on-failure.ksh`
- `maint/qemu/lab-openbsd78-upgrade.ksh`

## Typical usage

### Report mode

```sh
doas ./scripts/ops/maintenance-run.ksh --report
```

This validates the repo baseline and records a host snapshot without changing packages.

### Apply mode

```sh
doas ./scripts/ops/maintenance-run.ksh --apply
```

This performs the same preflight checks, applies updates through the public wrappers,
runs regression checks, and prints rollback guidance if anything fails.

## Rollback posture

OpenBSD package and base-system rollback is not treated as a magic button.
The public repo instead makes rollback explicit:

1. capture pre-change host state
2. use backup and DR tooling before risky maintenance windows
3. compare package and syspatch state after failure
4. restore repo-managed configs from the last known good state
5. re-run regression checks after each corrective action

## QEMU-first maintenance testing

Use the existing lab workflow to test maintenance changes before touching a real host.
The new helper `maint/qemu/lab-openbsd78-upgrade.ksh` syncs the public repo into a running lab VM and executes the maintenance workflow there.
