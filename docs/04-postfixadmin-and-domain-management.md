# PostfixAdmin and domain management

## Purpose

This document explains how the public `openbsd-mailstack` project uses
PostfixAdmin as the domain and mailbox administration layer for the SQL-backed
mail stack.

Phase 03 prepares the database-side and application-side foundation for:

- managing one or more hosted mail domains
- managing mailbox and alias records
- separating SQL credentials from system credentials
- preparing later Postfix and Dovecot phases to consume consistent domain data

## Why this matters

A public mail stack project needs a repeatable way to manage domains and
mailboxes. PostfixAdmin provides a familiar administrative interface and a SQL
schema that works well with virtual domain hosting.

For multi-domain deployments, this is especially useful because one server can
host several mail domains while keeping mailbox and alias management in one
place.

## What this phase expects from you

Before running Phase 03, you should know:

- the primary domain for the installation
- any additional domains you plan to host
- the database name to use for PostfixAdmin
- the SQL user to use for PostfixAdmin
- the SQL password for that SQL user
- the PostfixAdmin setup password, used to initialize the application safely

These values can be placed in:

- `config/domains.conf`
- `config/secrets.conf`

If they are missing, the apply script can prompt for them unless noninteractive
mode is enabled.

## Multi-domain guidance

If you plan to host more than one domain, define all of them in
`config/domains.conf`:

```sh
PRIMARY_DOMAIN="example.com"
DOMAINS="example.com example.net example.org"
```

Later phases can use this same domain list for:

- virtual domain SQL records
- DKIM key generation
- DNS record generation
- mailbox and alias examples
- TLS and policy documentation

For this reason, the domain list should be treated as the main source of truth
for hosted domains in the public repo workflow.

## What Phase 03 changes

The Phase 03 apply script is intentionally conservative. It does not install the
entire application stack by itself, but it prepares the public project for that
work by:

- validating domain and SQL inputs
- confirming MariaDB tools are present
- generating a public-safe local configuration template for PostfixAdmin
- generating a SQL summary file that later deployment steps can follow

## Outputs created by Phase 03

The apply script can create these local project files:

- `services/postfixadmin/config.local.php.example.generated`
- `services/postfixadmin/postfixadmin-sql-summary.txt`

These are helper artifacts for the repo workflow. They are not intended to
contain production secrets.

## Verification

The verify script checks:

- domains are valid
- SQL naming is valid
- key secret fields are present
- MariaDB client tooling exists
- generated helper files exist when expected

## Recommended usage

For experienced users:

- pre-fill the config files
- run the phase in noninteractive mode
- review the generated helper files before moving on

For newer users:

- run the script interactively
- answer the prompts carefully
- keep your real `config/secrets.conf` private

## Next step

After Phase 03 succeeds, the next logical phase is Postfix integration with SQL,
so that the MTA can consume the same domain and mailbox model.


## Phase 02 runtime note

This phase now uses the shared core runtime renderer and installer. Review `docs/configuration/core-runtime-and-config-wiring.md`, then run `./scripts/install/render-core-runtime-configs.ksh` to stage the live operator runtime tree under `.work/runtime/rootfs/`. Use `services/generated/rootfs/` only as the tracked sanitized example reference.
