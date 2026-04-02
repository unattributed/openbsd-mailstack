# Weekly Operator Workflow

## Purpose

This document defines the weekly public-safe review workflow for a deployed host or a serious QEMU validation baseline.

## Main script

Use:

- `scripts/ops/weekly-operator-review.ksh`

## Recommended weekly sequence

1. run the post-install checks
2. run the wider verify suite for the baseline phase range
3. review `.work/runtime/rootfs/` if you changed core runtime inputs or templates, review `.work/network-exposure/rootfs/` or `.work/identity/` if you changed network or DNS identity inputs, and review `.work/advanced/rootfs/` or `.work/advanced/sbom/` if you changed optional advanced assets
4. review operations-related warnings before making new changes

## Weekly command

```sh
./scripts/ops/weekly-operator-review.ksh
```

## What the script focuses on

- post-install validation
- verify coverage across the recommended early baseline
- service status when running on OpenBSD
- a wider non-destructive review cadence before new maintenance work

## Good times to run it

- before planned maintenance
- after package or base-system changes
- after changes to operator inputs
- after changes to runtime templates or phase scripts
