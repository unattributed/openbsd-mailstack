# Operator Workflow

## Purpose

This document provides a practical operator workflow for using the public project.

## Daily-use mindset

Treat the project as a controlled framework, not as a pile of scripts.

The basic operator cycle is:

1. prepare prerequisites
2. choose a deployment path
3. apply one phase
4. verify one phase
5. record what changed
6. continue only when the current phase is clean

## Suggested workflow

### For first-time deployment

1. complete install prerequisites
2. choose QEMU lab or direct host
3. run Phase 00
4. verify Phase 00
5. continue upward in order
6. stop and review at any failure

### For later changes

1. identify the phase or layer affected
2. review the phase narrative document
3. apply the relevant phase or script
4. run the verify script
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

## Current roadmap note

The public repo has strong coverage through Phase 16, but the original private project still contains later-phase material and operations doctrine that should be reconciled and published in future work.

That means operators should expect the public project to continue evolving beyond the current phase baseline.
