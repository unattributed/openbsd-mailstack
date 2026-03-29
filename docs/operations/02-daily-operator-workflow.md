# Daily Operator Workflow

## Purpose

This document defines the daily public-safe operator review workflow for a host that is already deployed or for a QEMU baseline that you are actively validating.

## Main script

Use:

- `scripts/ops/daily-operator-review.ksh`

## Recommended daily sequence

1. run the daily review script
2. inspect warnings and failures immediately
3. confirm you understand any service that is missing or not running
4. capture notable findings in your own ticket or notes system

## Daily command

```sh
./scripts/ops/daily-operator-review.ksh
```

## What the script focuses on

- live service status when running on OpenBSD
- presence of key installed config files
- core host checks such as disk usage and mail queue visibility when available
- a quick public-safe host review without mutating state

## When to escalate to a wider review

Move from the daily review to the weekly workflow when:

- you see repeated warnings
- a service is down unexpectedly
- you changed runtime config or phase outputs
- you are preparing for package or base-system maintenance
