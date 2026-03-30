# Dovecot authentication and mailbox delivery

## Purpose

This document explains how the public `openbsd-mailstack` project prepares
Dovecot to authenticate mailbox users and deliver mail into a Maildir-based
storage layout.

Phase 05 aligns Dovecot with the SQL-backed administrative data model used by
earlier phases. It prepares the public repo for:

- SQL-backed user authentication
- SQL-backed user lookup
- Maildir mailbox location planning
- shared mailbox layout across one or more hosted domains
- consistent UID and GID planning for virtual mail storage

## Why this matters

Once Postfix can identify hosted domains and mailbox addresses, Dovecot needs a
matching way to:

- authenticate the mailbox owner
- find the mailbox location
- expose a stable mail storage path
- support multiple hosted domains on one server

A SQL-backed Dovecot model allows the IMAP and LMTP side of the mail stack to
consume the same administrative data that PostfixAdmin manages.

## What this phase expects from you

Before running Phase 05, you should know:

- the primary hosted domain
- the full domain list
- the Dovecot SQL database name
- the Dovecot SQL username
- the Dovecot SQL password
- the desired mail location template
- the UID and GID to use for virtual mail storage

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

This allows later Dovecot and Postfix phases to share the same domain source of
truth for SQL lookups, mailbox examples, and documentation.

## What Phase 05 changes

The apply script is intentionally conservative. It prepares the repo workflow by:

- validating Dovecot SQL settings
- validating the mailbox storage model
- confirming Dovecot tools exist
- creating public-safe SQL and auth configuration examples
- creating a Dovecot mail configuration fragment
- creating a summary file for operator review

The generated files are helper artifacts. They do not contain the real SQL
password in cleartext.

## Outputs created by Phase 05

The apply script can create these local project files:

- `services/dovecot/dovecot-sql.conf.ext.example.generated`
- `services/dovecot/dovecot-auth.conf.fragment.example.generated`
- `services/dovecot/dovecot-mail.conf.fragment.example.generated`
- `services/dovecot/dovecot-sql-summary.txt`

## Verification

The verify script checks:

- domains are valid
- Dovecot SQL naming is valid
- key secret fields are present
- Dovecot tools exist
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

After Phase 05 succeeds, the next logical phase is TLS and certificate
automation, so IMAP, submission, and web components can use the same secure
certificate baseline.


## Phase 02 runtime note

This phase now uses the shared core runtime renderer and installer. Review `docs/configuration/core-runtime-and-config-wiring.md`, then run `./scripts/install/render-core-runtime-configs.ksh` to stage the live operator runtime tree under `.work/runtime/rootfs/`. Use `services/generated/rootfs/` only as the tracked sanitized example reference.
