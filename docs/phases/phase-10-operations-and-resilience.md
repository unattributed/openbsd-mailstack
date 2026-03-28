# Phase 10, operations and resilience

## Purpose

Phase 10 prepares the operations, monitoring, and resilience baseline for the
public `openbsd-mailstack` project.

This phase defines how the project should approach:

- local service health review
- backup planning
- log summarization
- operator alert targeting
- conservative maintenance guidance

## Who this phase is for

This phase is required for users who want a practical operational baseline for:

- service review
- backup planning
- ongoing maintenance
- early incident identification

## Information you need before starting

You should have:

- a valid `MAIL_HOSTNAME`
- a valid `ALERT_EMAIL`
- a valid `OPS_BACKUP_MODE`
- a valid `OPS_RETENTION_DAYS`
- valid yes/no choices for:
  - `OPS_ENABLE_ALERTS`
  - `OPS_ENABLE_HEALTHCHECKS`
  - `OPS_ENABLE_LOG_SUMMARY`

## How user customization works

This phase supports two ways to provide values.

### Method 1, configuration files

Recommended for repeatable deployments.

Edit:

- `config/system.conf`
- `config/network.conf`

### Method 2, interactive prompts

If required values are missing, the apply script can prompt for them.

This is useful for first-time users, but config files remain the better long-term
option because they make later phases easier and more deterministic.

Do not edit the scripts themselves to change deployment values.

## Operational model

The public repo uses this MVP operational model:

- local-first checks
- no destructive repair actions
- generated guidance instead of blind automation
- operator-controlled alert target
- backup planning for core mail stack state

## Preconditions

Before running this phase:

- Phase 00 through Phase 09 should be complete
- core mail stack planning should already exist
- the primary mail hostname should already be set
- the operator should know what alert email to document

## What the script changes

The apply script can:

- validate operations-related inputs
- validate retention and toggle values
- generate health check and service review helpers
- generate backup and log summary notes
- write an operations summary for review

This phase does not claim to fully automate production operations by itself. It
prepares a clean, public-repo-friendly baseline for that work.

## Run the phase

From the project root:

```sh
doas ./scripts/phases/phase-10-apply.ksh
```

For deterministic config-only execution:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-10-apply.ksh
```

If you want the script to save prompted values back into config files, use:

```sh
doas env SAVE_CONFIG=yes ./scripts/phases/phase-10-apply.ksh
```

## Verify the phase

Run:

```sh
./scripts/phases/phase-10-verify.ksh
```

## What success looks like

A successful result means:

- operational settings are valid
- helper files were generated
- the repo now includes a public operations baseline

## Troubleshooting

### The script says retention is invalid

Use a numeric value such as:

- `7`
- `14`
- `30`

### The script says a yes/no toggle is invalid

Use:

- `yes`
- `no`

### The verify script warns that generated files are missing

Run the apply phase first, then rerun the verify phase.

## Audience notes

### If you are new to self-hosting

Use the prompts, then review the generated files carefully before building any
live operational automation.

### If you are already comfortable with OpenBSD service operations

Pre-fill the config files, run the phase in noninteractive mode, and treat the
generated helper outputs as review artifacts before live implementation.

## Next phase

After Phase 10 succeeds, continue with optional advanced backup, DR, and deeper
monitoring tracks as needed.
