# Postfix core and SQL integration

## Purpose

This document explains how the public `openbsd-mailstack` project prepares the
Postfix MTA to consume SQL-backed virtual domain data.

Phase 04 focuses on the Postfix side of the mail path. It does not attempt to
finalize all mail delivery behavior, but it prepares the public repo for:

- SQL-backed hosted domain lookups
- SQL-backed mailbox lookups
- SQL-backed alias lookups
- multi-domain mail routing preparation
- separation of Postfix database credentials from other service credentials

## Why this matters

Once multiple hosted domains exist, Postfix needs a consistent way to decide:

- which domains are local virtual domains
- which addresses represent valid mailboxes
- which addresses should be treated as aliases

A SQL-backed model allows those decisions to be driven from the same
administrative data source that PostfixAdmin manages.

## What this phase expects from you

Before running Phase 04, you should know:

- the primary domain
- the full hosted domain list
- the Postfix SQL database name
- the Postfix SQL username
- the Postfix SQL password
- the virtual transport to use, normally `dovecot`

These values can be placed in:

- `config/domains.conf`
- `config/secrets.conf`

If they are missing, the apply script can prompt for them unless noninteractive
mode is enabled.

## Multi-domain guidance

If you plan to host more than one domain, keep all domains in `DOMAINS`:

```sh
PRIMARY_DOMAIN="example.com"
DOMAINS="example.com example.net example.org"
```

This allows later phases to generate a consistent set of Postfix and Dovecot
examples for all hosted domains.

## What Phase 04 changes

The apply script is intentionally conservative. It prepares the repo workflow by:

- validating Postfix SQL settings
- confirming Postfix tooling exists
- creating public-safe SQL lookup map examples
- creating a public-safe Postfix main.cf fragment example
- creating a summary file for operator review

The generated files are helper artifacts. They do not contain the real SQL
password in cleartext.

## Outputs created by Phase 04

The apply script can create these local project files:

- `services/postfix/main.cf.fragment.example.generated`
- `services/postfix/mysql-virtual-domains.cf.example.generated`
- `services/postfix/mysql-virtual-mailboxes.cf.example.generated`
- `services/postfix/mysql-virtual-aliases.cf.example.generated`
- `services/postfix/postfix-sql-summary.txt`

## Verification

The verify script checks:

- domains are valid
- Postfix SQL naming is valid
- key secret fields are present
- Postfix tools exist
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

After Phase 04 succeeds, the next logical phase is Dovecot integration, so that
mailbox authentication and delivery can consume the same SQL-backed domain model.
