# Phase 04, Postfix core and SQL integration

## Purpose

Phase 04 prepares the Postfix core configuration and SQL lookup wiring for the
public `openbsd-mailstack` project.

This phase is where the project begins to define how Postfix will query the
SQL-backed administrative data model for hosted domains, virtual mailboxes, and
aliases.

It focuses on:

- validating hosted domain settings
- validating Postfix SQL settings
- checking for required Postfix commands
- generating public-safe SQL map examples
- generating a Postfix configuration fragment for operator review

## Who this phase is for

This phase is required for users who want Postfix to consume SQL-backed virtual
domain and mailbox data.

That includes most users who want:

- one or more hosted mail domains
- virtual mailboxes
- virtual aliases
- an administrative flow that matches PostfixAdmin-backed SQL data

## Information you need before starting

You should have:

- a valid `PRIMARY_DOMAIN`
- a valid `DOMAINS` list for all hosted mail domains
- a Postfix SQL database name
- a Postfix SQL user
- a Postfix SQL password
- a `POSTFIX_VIRTUAL_TRANSPORT`, normally `dovecot`

Optional but useful:

- example mailbox addresses in `INITIAL_MAILBOXES`
- a domain administration email in `DOMAIN_ADMIN_EMAIL`

## How user customization works

This phase supports two ways to provide values.

### Method 1, configuration files

Recommended for repeatable deployments.

Edit:

- `config/domains.conf`
- `config/secrets.conf`

### Method 2, interactive prompts

If required values are missing, the apply script can prompt for them.

This is useful for first-time users, but config files remain the better long-term
option because they make later phases easier and more deterministic.

Do not edit the scripts themselves to change deployment values.

## Multi-domain behavior

This phase is multi-domain aware.

If `DOMAINS` contains several domains, the script validates each one and uses
the domain list when generating helper outputs. The generated files are intended
to support later phases that create working Postfix and Dovecot SQL-backed
deployments for all hosted domains.

## Preconditions

Before running this phase:

- Phase 00 should be complete
- Phase 01 should be complete
- Phase 02 should be complete
- Phase 03 should be complete
- Postfix tools should be installed
- you should know the SQL naming and password values you intend to use

## What the script changes

The apply script can:

- validate and normalize domain-related inputs
- validate Postfix SQL identifiers
- validate secret fields
- create `services/postfix/` if missing
- write SQL lookup map examples
- write a Postfix `main.cf` fragment example
- write a summary file for review

This phase does not claim to fully deploy the live Postfix service by itself. It
prepares a clean, public-repo-friendly baseline for that deployment.

## Run the phase

From the project root:

```sh
doas ./scripts/phases/phase-04-apply.ksh
```

For deterministic config-only execution:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-04-apply.ksh
```

If you want the script to save prompted values back into config files, use:

```sh
doas env SAVE_CONFIG=yes ./scripts/phases/phase-04-apply.ksh
```

## Verify the phase

Run:

```sh
./scripts/phases/phase-04-verify.ksh
```

## What success looks like

A successful result means:

- the domain list is valid
- Postfix SQL values are valid
- required Postfix commands are available
- helper files were generated in `services/postfix/`
- the repo is ready for the next SQL-consuming mail phase

## Troubleshooting

### The script says a domain is invalid

Review `PRIMARY_DOMAIN` and `DOMAINS` in `config/domains.conf`. Each domain
should be a normal DNS domain name.

### The script says a SQL name is invalid

Use simple names such as:

- `postfixadmin`
- `postfix`
- `roundcube`

Avoid spaces and punctuation other than underscore.

### The script says a required secret is missing

Add the missing value to `config/secrets.conf`, or rerun the phase interactively
and answer the prompt.

### The verify script warns that Postfix tools are missing

Install the expected Postfix package and rerun the verify step before continuing.

## Audience notes

### If you are new to self-hosting

Use the prompts, then review the generated helper files so you understand how
Postfix SQL lookups are being prepared.

### If you are already comfortable with OpenBSD and SQL mail stacks

Pre-fill the config files, run the phase in noninteractive mode, and treat the
generated helper outputs as review artifacts before your live deployment step.

## Next phase

After Phase 04 succeeds, continue to the phase that wires Dovecot into the same
SQL model for mailbox authentication and delivery.
