# Maintenance, upgrades, and regression workflow

## Purpose

This workflow is the operator-facing day-2 path for OpenBSD updates and safe change validation.

## Baseline routine

1. confirm backup and DR tooling is working
2. review monitoring and alert output
3. run maintenance preflight in report mode
4. review the generated host snapshot
5. run maintenance apply in a defined change window
6. confirm regression checks pass
7. review rollback guidance immediately if anything fails

## Commands

### Preflight only

```sh
doas ./scripts/ops/maintenance-preflight.ksh
```

### Full report mode

```sh
doas ./scripts/ops/maintenance-run.ksh --report
```

### Apply mode

```sh
doas ./scripts/ops/maintenance-run.ksh --apply
```

### Rollback guidance only

```sh
doas ./scripts/ops/maintenance-rollback-plan.ksh
```

## What to inspect after maintenance

- `syspatch -l`
- `pkg_info -q | sort`
- `rcctl check postfix dovecot rspamd redis clamd freshclam nginx`
- latest maintenance snapshot under `MAINTENANCE_STATE_DIR`
- output from `maint/regression-test.ksh`

## Lab-first recommendation

Use the QEMU helper first whenever the change touches package baselines, OpenBSD upgrades, or sensitive runtime behavior.
