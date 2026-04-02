# Phase 02, MariaDB baseline

## Purpose

Phase 02 establishes the SQL baseline for the public `openbsd-mailstack`
project on OpenBSD 7.8.

This phase prepares the host for later application phases that depend on
MariaDB, especially PostfixAdmin and Roundcube.


## Public implementation note

In the current public repo, this phase uses the shared core runtime renderer, but it now also writes a targeted phase summary and uses a phase-scoped verify profile.

That means the phase remains aligned to the shared render path while still asserting the specific templates and rendered assets that matter for this layer.

## Who this phase is for

This phase is required for users who want:

- SQL-backed domain and mailbox management
- PostfixAdmin
- Roundcube
- multi-domain administration from shared SQL tables

If you do not intend to use the SQL-backed parts of this project, this phase
may be optional, but the default public mailstack design assumes it is present.

## Information you need before starting

Before you run this phase, gather or decide:

- the MariaDB root password for this host
- the mailstack database name
- the mailstack database user
- the mailstack database password
- the PostfixAdmin database name and user
- the Roundcube database name and user

For a typical multi-domain deployment, the same database service can manage all
hosted domains. You do not need a separate MariaDB instance or a separate
database server for each domain.

## How user customization works

This phase supports two ways to provide values.

### Method 1, configuration files

Create and edit your real config files:

```sh
cp config/domains.conf.example config/domains.conf
cp config/secrets.conf.example config/secrets.conf
```

Then add your real values.

### Method 2, interactive prompts

If required values are missing, the apply and verify scripts can prompt you for
them, unless noninteractive mode is enabled.

### Recommended approach

Use config files for repeatable deployments. Use prompts only to fill gaps.

## What this phase changes

The Phase 02 apply script is conservative and focused on baseline readiness.

It can:

- validate your SQL-related configuration values
- check the MariaDB package and service state
- guide you through secure storage of SQL credentials
- optionally create a real `config/secrets.conf` if one does not yet exist
- check whether MariaDB is initialized and listening locally
- verify that your database naming model is suitable for later multi-domain use

It does not automatically create every later application schema.

## Preconditions

Before running this phase:

- Phase 00 should already be complete
- Phase 01 should already be complete
- the host must be OpenBSD 7.8
- the project must be run from the repository root

## Run the phase

```sh
doas ./scripts/phases/phase-02-apply.ksh
```

To force config-only mode and disable prompts:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-02-apply.ksh
```

## Verify the phase

```sh
./scripts/phases/phase-02-verify.ksh
```

## What success looks like

A successful Phase 02 result means:

- the expected MariaDB-related values are present and valid
- the secrets file exists or can be created safely
- the MariaDB package and service checks are understood
- the host is ready for later SQL-backed mail phases

## Troubleshooting

### The script reports missing SQL credentials

Add the missing values to `config/secrets.conf` or rerun with prompting enabled.

### The script reports MariaDB is not installed

That is acceptable at this stage if you are still preparing the public config,
but later phases will require a real package installation and service enablement.

### The script reports MariaDB is not listening

That usually means the service is not initialized, not enabled, or not running
yet. Review the Phase 02 output and later installation steps.

## Audience notes

### New users

You can use the prompts to understand what each SQL value means.

### Intermediate users

Fill the config files first, then run the script.

### Advanced users

Use noninteractive mode and keep the secrets file local and private.

## Multi-domain reminder

MariaDB is shared infrastructure. Multi-domain hosting is usually implemented
inside shared SQL tables, not by multiplying database servers.


## Phase 02 runtime note

This phase now uses the shared core runtime renderer and installer. Review `docs/configuration/core-runtime-and-config-wiring.md`, then run `./scripts/install/render-core-runtime-configs.ksh` to stage the live operator runtime tree under `.work/runtime/rootfs/`. Use `services/generated/rootfs/` only as the tracked sanitized example reference.
