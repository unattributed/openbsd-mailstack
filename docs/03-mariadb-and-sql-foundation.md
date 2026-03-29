# MariaDB and SQL foundation

This document explains the SQL baseline used by the public `openbsd-mailstack`
project.

## Why this phase exists

The mail stack needs a database foundation before later phases can configure:

- hosted domains
- mailbox accounts
- aliases
- administrative web interfaces
- domain-level policies for one or many mail domains

This phase prepares a clean MariaDB baseline for those later steps.

## What this phase does

Phase 02 focuses on:

- checking that the host is still on OpenBSD 7.8
- collecting the SQL settings needed for the mail stack
- documenting the database names and service users
- preparing a public-safe SQL planning baseline
- checking whether the database service is installed, enabled, and reachable
- helping the user understand what must exist before PostfixAdmin and Roundcube
  are introduced

This phase is deliberately conservative. It does not create production schemas
for every later service automatically without user review.

## Multi-domain note

MariaDB itself does not need one database per hosted domain.

For a typical multi-domain deployment:

- one database service is enough
- one PostfixAdmin database can manage many hosted domains
- one Roundcube database can support webmail for users across many hosted domains
- the domain separation is handled in the SQL tables and application logic

Example:

- `PRIMARY_DOMAIN="example.com"`
- `DOMAINS="example.com example.net example.org"`

A later SQL-backed mail application can store all of those domains inside one
domain table, one mailbox table, and related alias and policy tables.

## What the user should know before running this phase

Gather or decide the following:

- the MariaDB root password you want to use on this host
- the service database names you plan to use
- the service database usernames you plan to use
- whether you want a single database for the mail stack or separate databases
  for each application

The default public examples assume:

- one mailstack database
- one PostfixAdmin database
- one Roundcube database

## How to provide the values

You can use either:

1. `config/secrets.conf` and `config/domains.conf`, recommended
2. interactive prompting for missing values

For repeatable deployments, fill the config files first.

## Recommended service model

For most users:

- use one MariaDB service
- use one PostfixAdmin database
- use one Roundcube database
- manage multiple domains through shared SQL tables, not per-domain databases

## What comes next

After this phase is successful, later phases can safely build:

- PostfixAdmin SQL schema and admin accounts
- Postfix SQL lookup maps
- Dovecot SQL-backed user and password lookups
- Roundcube SQL storage

## Security note

The real `config/secrets.conf` file must remain private and must never be
committed to Git.


## Phase 02 runtime note

This phase now uses the shared core runtime renderer and installer. Review `docs/configuration/core-runtime-and-config-wiring.md`, then run `./scripts/install/render-core-runtime-configs.ksh` to stage sanitized service configs under `services/generated/rootfs/`.
