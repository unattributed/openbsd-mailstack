# Phase 03, PostfixAdmin and SQL wiring

## Purpose

Phase 03 prepares the PostfixAdmin and SQL foundation for the public
`openbsd-mailstack` project.

This phase is where the project begins to formalize domain and mailbox
management for one or more hosted domains.

It focuses on:

- validating the hosted domain list
- validating SQL and PostfixAdmin settings
- checking MariaDB client access prerequisites
- generating local helper templates for PostfixAdmin integration
- preparing later Postfix and Dovecot phases to use the same SQL model

## Who this phase is for

This phase is required for users who want SQL-backed virtual domain hosting.

That includes most users who want:

- more than one hosted mail domain
- a mailbox administration interface
- a structured path toward Postfix virtual domains and virtual mailboxes

## Information you need before starting

You should have:

- a valid `PRIMARY_DOMAIN`
- a valid `DOMAINS` list for all hosted mail domains
- a MariaDB root password
- a PostfixAdmin database name
- a PostfixAdmin database user
- a PostfixAdmin database password
- a PostfixAdmin setup password

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

This is useful for first-time users, but config files are still the better
long-term option because they make future runs and later phases easier.

Do not edit the scripts themselves to change deployment values.

## Multi-domain behavior

This phase is multi-domain aware.

If `DOMAINS` contains several domains, the script will validate each one and use
that domain list when generating helper outputs. The generated outputs are meant
to support later phases that create SQL mappings, DNS records, and administrative
artifacts for all hosted domains.

## Preconditions

Before running this phase:

- Phase 00 should be complete
- Phase 01 should be complete
- Phase 02 should be complete
- MariaDB client tooling should be installed
- you should know the SQL naming and password values you intend to use

## What the script changes

The apply script can:

- validate and normalize domain-related inputs
- validate SQL identifiers
- validate secret fields
- create `services/postfixadmin/` if missing
- write a local PostfixAdmin configuration example file
- write a SQL summary file for review

This phase does not claim to fully deploy the live PostfixAdmin application on
its own. It prepares a clean, public-repo-friendly baseline for that deployment.

## Run the phase

From the project root:

```sh
doas ./scripts/phases/phase-03-apply.ksh
```

For deterministic config-only execution:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-03-apply.ksh
```

If you want the script to save prompted values back into config files, use:

```sh
doas env SAVE_CONFIG=yes ./scripts/phases/phase-03-apply.ksh
```

## Verify the phase

Run:

```sh
./scripts/phases/phase-03-verify.ksh
```

## What success looks like

A successful result means:

- the domain list is valid
- SQL values are valid
- required MariaDB client commands are available
- helper files were generated in `services/postfixadmin/`
- the repo is ready for the next SQL-consuming phase

## Troubleshooting

### The script says a domain is invalid

Review `PRIMARY_DOMAIN` and `DOMAINS` in `config/domains.conf`. Each domain
should be a normal DNS domain name.

### The script says a SQL name is invalid

Use simple names such as:

- `postfixadmin`
- `roundcube`
- `mailstack`

Avoid spaces and punctuation other than underscore.

### The script says a required secret is missing

Add the missing value to `config/secrets.conf`, or rerun the phase interactively
and answer the prompt.

### The verify script warns that MariaDB client tools are missing

Install the expected MariaDB client package and rerun the verify step before
continuing.

## Audience notes

### If you are new to self-hosting

Use the prompts, then review the generated helper files so you understand how
SQL-backed mail management is being prepared.

### If you are already comfortable with OpenBSD and SQL mail stacks

Pre-fill the config files, run the phase in noninteractive mode, and treat the
generated helper outputs as review artifacts before your live deployment step.

## Next phase

After Phase 03 succeeds, continue to the phase that wires Postfix into the SQL
model for hosted domains, aliases, and mailbox routing.


## Phase 02 runtime note

This phase now uses the shared core runtime renderer and installer. Review `docs/configuration/core-runtime-and-config-wiring.md`, then run `./scripts/install/render-core-runtime-configs.ksh` to stage sanitized service configs under `services/generated/rootfs/`.
