# Operator Workflow

## Purpose

This document describes the operator workflow for using `openbsd-mailstack` after prerequisites, local inputs, and the initial runtime rendering path are in place.

## Daily-use mindset

Treat the project as a controlled framework, not as a pile of scripts.

The basic operator cycle is:

1. prepare prerequisites and local inputs
2. choose a deployment path
3. apply one phase or one phase range
4. verify what changed
5. review generated artifacts and host state
6. record what changed
7. continue only when the current state is understood

## Suggested workflow

### For first-time deployment

1. complete install prerequisites
2. choose QEMU lab or direct host
3. render the core runtime tree
4. run the public phase sequence for the baseline you want
5. run the post-install checks
6. continue to daily and weekly operator reviews
7. add monitoring, backup, DR, maintenance, and hardening layers as the host stabilizes

### For later changes

1. identify the phase or operational layer affected
2. review the relevant phase narrative and install or operations docs
3. rerender the runtime or apply the relevant phase
4. run the matching verify script or the post-install checks
5. inspect generated artifacts and runtime state
6. commit only after the result is understood

### For autonomous installer work

1. generate a local profile
2. render the installer pack
3. inspect the rendered outputs
4. test in the QEMU lab if possible
5. only then use on real hardware

## Repo discipline

- keep local profiles untracked
- keep provider secrets outside Git
- keep generated private artifacts outside Git unless they are explicitly public-safe examples
- commit documentation and public tooling, not operator state

## Recommended operator documents

Use these together:

- [Install order and phase sequence](../install/09-install-order-and-phase-sequence.md)
- [Post-install checks](../install/12-post-install-checks.md)
- [Daily operator workflow](02-daily-operator-workflow.md)
- [Weekly operator workflow](03-weekly-operator-workflow.md)
- [Monitoring, diagnostics, and reporting](05-monitoring-diagnostics-and-reporting.md)
- [Maintenance, upgrades, and regression](06-maintenance-upgrades-and-regression.md)
- [Security hardening and secrets operations](08-security-hardening-and-secrets-ops.md)

## Current public state

The public repository now supports a full public-safe operator path for install, validation, operations, backup, recovery planning, maintenance, network exposure control, hardening, and runtime secret layout.

Operators still provide their own local values, accounts, secrets, and exposure policy, which is part of the public design model.
