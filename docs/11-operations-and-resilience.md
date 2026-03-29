# Operations and resilience

## Purpose

This document explains how the public `openbsd-mailstack` project prepares the operations, monitoring, and resilience baseline for the platform.

Phase 10 standardizes the public operational model around:

- local-first health checks
- backup planning for critical state
- service status review guidance
- log summary generation
- non-destructive operational artifacts
- optional alert email configuration
- daily and weekly operator review cadence

## Why this matters

A mail platform is not complete when services merely exist. Operators also need

- a repeatable way to check whether services are up
- a way to understand what should be backed up
- a way to summarize important logs
- a way to identify likely operational regressions
- a way to review core readiness without changing production state

This phase prepares the repo for those needs without forcing a live operational automation model too early.

## Public operations baseline

Use this pattern:

```sh
MAIL_HOSTNAME="mail.example.com"
ALERT_EMAIL="ops@example.com"
OPS_BACKUP_MODE="local"
OPS_RETENTION_DAYS="14"
OPS_ENABLE_ALERTS="yes"
OPS_ENABLE_HEALTHCHECKS="yes"
OPS_ENABLE_LOG_SUMMARY="yes"
```

In that model:

- health checks are generated locally
- backup notes target the critical mail stack state
- alerts remain an optional operator-controlled feature
- nothing destructive is enabled by default

## What this phase expects from you

Before running Phase 10, you should know:

- the operational alert email target
- whether you want local backup guidance
- the retention period you want to document
- whether health checks should be enabled
- whether log summary generation should be enabled

These values can be placed in:

- `config/system.conf`
- `config/network.conf`

If they are missing, the apply script can prompt for them unless noninteractive mode is enabled.

## What Phase 10 changes

The apply script is intentionally conservative. It prepares the repo workflow by:

- validating operational settings
- validating retention and alert values
- confirming basic OpenBSD service tools exist
- generating public-safe health check scripts
- generating backup notes and monitoring summaries
- writing an operational summary for review

The generated files are helper artifacts. They are intended to guide later live deployment and maintenance on OpenBSD 7.8.

## Outputs created by Phase 10

The apply script can create these local project files:

- `services/ops/healthcheck.example.generated`
- `services/ops/rcctl-review.example.generated`
- `services/backup/backup-plan.example.generated`
- `services/monitoring/log-summary.example.generated`
- `services/ops/operations-summary.txt`

## Verification and operator cadence

The verify script checks:

- operational settings are valid
- required commands exist
- generated helper files exist when expected

For ongoing public-safe review, use:

- `./scripts/verify/run-post-install-checks.ksh`
- `./scripts/ops/daily-operator-review.ksh`
- `./scripts/ops/weekly-operator-review.ksh`

## Recommended usage

For experienced users:

- pre-fill the config files
- run the phase in noninteractive mode
- review the generated helper files before moving on
- adopt the daily and weekly review scripts after deployment

For newer users:

- run the script interactively
- answer the prompts carefully
- use the generated files as implementation guides, not as blind automation
- start with QEMU before changing a real host

## Next step

After Phase 10 succeeds, the public repo now has a backup and DR layer plus a practical monitoring baseline. The next logical work is to extend those layers selectively where private material can be generalized safely.
