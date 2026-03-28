# Phase 05, Dovecot authentication and mailbox delivery

## Purpose

Phase 05 prepares Dovecot authentication, SQL wiring, and mailbox delivery
planning for the public `openbsd-mailstack` project.

This phase is where the project begins to define how Dovecot will query the
SQL-backed administrative data model for mailbox authentication and mailbox
location.

It focuses on:

- validating hosted domain settings
- validating Dovecot SQL settings
- checking for required Dovecot commands
- generating public-safe Dovecot SQL and auth examples
- generating a Dovecot mail configuration fragment for operator review

## Who this phase is for

This phase is required for users who want Dovecot to consume SQL-backed virtual
mailbox data.

That includes most users who want:

- one or more hosted mail domains
- IMAP mailbox access
- LMTP or Maildir delivery planning
- an administrative flow that matches PostfixAdmin-backed SQL data

## Information you need before starting

You should have:

- a valid `PRIMARY_DOMAIN`
- a valid `DOMAINS` list for all hosted mail domains
- a Dovecot SQL database name
- a Dovecot SQL user
- a Dovecot SQL password
- a `DOVECOT_MAIL_LOCATION`, normally `maildir:/var/vmail/%d/%n`
- a virtual mail UID and GID, for example `2000`

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
to support later phases that create working Dovecot and Postfix SQL-backed
deployments for all hosted domains.

## Preconditions

Before running this phase:

- Phase 00 should be complete
- Phase 01 should be complete
- Phase 02 should be complete
- Phase 03 should be complete
- Phase 04 should be complete
- Dovecot tools should be installed
- you should know the SQL naming and password values you intend to use

## What the script changes

The apply script can:

- validate and normalize domain-related inputs
- validate Dovecot SQL identifiers
- validate secret fields
- create `services/dovecot/` if missing
- write Dovecot SQL, auth, and mail fragments
- write a summary file for review

This phase does not claim to fully deploy the live Dovecot service by itself. It
prepares a clean, public-repo-friendly baseline for that deployment.

## Run the phase

From the project root:

```sh
doas ./scripts/phases/phase-05-apply.ksh
```

For deterministic config-only execution:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-05-apply.ksh
```

If you want the script to save prompted values back into config files, use:

```sh
doas env SAVE_CONFIG=yes ./scripts/phases/phase-05-apply.ksh
```

## Verify the phase

Run:

```sh
./scripts/phases/phase-05-verify.ksh
```

## What success looks like

A successful result means:

- the domain list is valid
- Dovecot SQL values are valid
- required Dovecot commands are available
- helper files were generated in `services/dovecot/`
- the repo is ready for the next mail phase

## Troubleshooting

### The script says a domain is invalid

Review `PRIMARY_DOMAIN` and `DOMAINS` in `config/domains.conf`. Each domain
should be a normal DNS domain name.

### The script says a SQL name is invalid

Use simple names such as:

- `postfixadmin`
- `dovecot`
- `roundcube`

Avoid spaces and punctuation other than underscore.

### The script says a required secret is missing

Add the missing value to `config/secrets.conf`, or rerun the phase interactively
and answer the prompt.

### The verify script warns that Dovecot tools are missing

Install the expected Dovecot package and rerun the verify step before continuing.

## Audience notes

### If you are new to self-hosting

Use the prompts, then review the generated helper files so you understand how
Dovecot SQL lookups and Maildir planning are being prepared.

### If you are already comfortable with OpenBSD and SQL mail stacks

Pre-fill the config files, run the phase in noninteractive mode, and treat the
generated helper outputs as review artifacts before your live deployment step.

## Next phase

After Phase 05 succeeds, continue to the phase that prepares TLS and certificate
automation for the mail and web stack.
