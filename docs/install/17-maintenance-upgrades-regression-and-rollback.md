# Maintenance, upgrades, regression, and rollback workflow

## Purpose

This document shows how to use the public maintenance layer after the base mail stack, backup and DR path, and monitoring baseline are already in place.

## Recommended order

1. complete the normal install and post-install checks
2. install backup and DR assets
3. install monitoring and diagnostics assets
4. verify maintenance assets
5. run maintenance in report mode first
6. rehearse the same workflow in QEMU where practical
7. only then run maintenance in apply mode on the real host

## Inputs

Create a local maintenance input file from:

- `config/maintenance.conf.example`

Recommended location:

- `config/local/maintenance.conf`

Useful values include:

- `MAINTENANCE_STATE_DIR`
- `ALERT_EMAIL`
- `REGRESSION_PROBE_TO`
- `PKG_ADD_TIMEOUT_SECS`
- `MAINTENANCE_REQUIRE_CLEAN_GIT`
- `MAINTENANCE_ENABLE_SECRET_GUARD`
- `MAINTENANCE_ENABLE_DESIGN_AUTHORITY`

## Verify the layer is present

```sh
./scripts/verify/verify-maintenance-assets.ksh
```

## Optional host-side install

If you want the maintenance helpers in `/usr/local/sbin`:

```sh
doas ./scripts/install/install-maintenance-assets.ksh
```

By default, this installs the helpers but does not patch root cron automatically.

## Report mode first

```sh
doas ./scripts/ops/maintenance-run.ksh --report
```

This should:

- confirm the repo is in a safe state for maintenance
- run repo-secret and design-authority checks when enabled
- capture a pre-change host snapshot
- show what would be done next

## Apply mode

```sh
doas ./scripts/ops/maintenance-run.ksh --apply
```

This should:

- run `maint/openbsd-syspatch.ksh --apply`
- run `maint/openbsd-pkg-upgrade.ksh --apply`
- run `maint/regression-test.ksh`
- print rollback guidance if a step fails

## QEMU rehearsal

If you already have a running lab VM reachable through the existing SSH guard settings:

```sh
ksh maint/qemu/lab-openbsd78-upgrade.ksh --report
```

Then, once satisfied:

```sh
ksh maint/qemu/lab-openbsd78-upgrade.ksh --apply
```

## Weekly cadence

Use the existing weekly operator workflow together with the new maintenance layer.
If you want a root cron entry generated for the host, run:

```sh
doas ksh maint/install-weekly-ops-cron.ksh
```
