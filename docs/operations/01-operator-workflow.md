# Operator Workflow

## Purpose

This document provides the public operator workflow for using the project after the install and core runtime phases have been reconciled.

## Daily-use mindset

Treat the project as a controlled framework, not as a pile of scripts.

The basic operator cycle is:

1. prepare prerequisites
2. choose a deployment path
3. apply one phase or one phase range
4. verify what you changed
5. record what changed
6. continue only when the current state is understood

## Suggested workflow

### For first-time deployment

1. complete install prerequisites
2. choose QEMU lab or direct host
3. render the core runtime tree
4. run the public phase sequence
5. run the post-install checks
6. continue to daily and weekly operator reviews

### For later changes

1. identify the phase or layer affected
2. review the phase narrative document
3. apply the relevant phase or rerender the runtime
4. run the verify script or the post-install checks
5. inspect generated artifacts
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

- `docs/install/09-install-order-and-phase-sequence.md`
- `docs/install/12-post-install-checks.md`
- `docs/operations/02-daily-operator-workflow.md`
- `docs/operations/03-weekly-operator-workflow.md`

## Current roadmap note

The public repo now supports the first install, test, and operations path, but the original private project still contains later-phase material and operations doctrine that should be reconciled and published in future work.
