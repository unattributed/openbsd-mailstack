# Phase 07, filtering and anti-abuse

## Purpose

Phase 07 prepares mail filtering and anti-abuse guidance for the public
`openbsd-mailstack` project.

This phase defines how Postfix, Rspamd, Redis, optional ClamAV, and optional
Brevo relay support should align using a localhost-first layout suitable for one
public mail host serving one or more hosted domains.

It focuses on:

- validating filtering settings
- validating Rspamd bind addresses
- validating Redis settings
- checking for required filtering commands
- generating public-safe filtering fragments for review

## External dependency

If you intend to use Brevo as an outbound smart-relay or deliverability support
layer, complete:

- `docs/install/03-brevo-account-and-relay-setup.md`

Specifically:

- the operator must already have a Brevo account
- any required Brevo users or admin users must already exist
- API and SMTP keys must already exist and be stored securely outside the repository
- any sender-domain authentication records must be managed outside Git


## Public implementation note

In the current public repo, this phase uses the shared core runtime renderer, but it now also writes a targeted phase summary and uses a phase-scoped verify profile.

That means the phase remains aligned to the shared render path while still asserting the specific templates and rendered assets that matter for this layer.

## Who this phase is for

This phase is required for users who want a practical filtering baseline for:

- spam scoring
- anti-abuse policy
- Postfix milter integration
- optional antivirus scanning
- multi-domain mail hosting behind one mail hostname
- optional smart-relay support for self-hosted outbound delivery

## Information you need before starting

You should have:

- a valid `MAIL_HOSTNAME`
- a valid `PRIMARY_DOMAIN`
- a valid `RSPAMD_MILTER_BIND`
- a valid `RSPAMD_NORMAL_BIND`
- a valid `RSPAMD_CONTROLLER_BIND`
- a valid `RSPAMD_REDIS_HOST`
- a valid `RSPAMD_REDIS_PORT`
- a valid `RSPAMD_CLAMAV_ENABLED` choice

## How user customization works

This phase supports two ways to provide values.

### Method 1, configuration files

Recommended for repeatable deployments.

Edit:

- `config/system.conf`

### Method 2, interactive prompts

If required values are missing, the apply script can prompt for them.

This is useful for first-time users, but config files remain the better long-term
option because they make later phases easier and more deterministic.

Do not edit the scripts themselves to change deployment values.

## Public filtering model

This public repo uses:

- one public mail hostname
- one local Rspamd deployment
- optional local ClamAV integration
- one or more hosted domains
- Postfix milter integration over localhost
- optional Brevo relay support when direct outbound delivery is not appropriate

Example:

```sh
MAIL_HOSTNAME="mail.example.com"
PRIMARY_DOMAIN="example.com"
DOMAINS="example.com example.net example.org"

RSPAMD_MILTER_BIND="127.0.0.1:11332"
RSPAMD_NORMAL_BIND="127.0.0.1:11333"
RSPAMD_CONTROLLER_BIND="127.0.0.1:11334"
RSPAMD_REDIS_HOST="127.0.0.1"
RSPAMD_REDIS_PORT="6379"
RSPAMD_CLAMAV_ENABLED="yes"
```

## Security requirement

Do NOT:

- hardcode Brevo API keys in scripts
- hardcode Brevo SMTP keys in tracked config files
- commit sender credentials or relay secrets to Git

All live Brevo usage must reference secure runtime values or protected local files.

## Preconditions

Before running this phase:

- Phase 00 through Phase 06 should be complete
- Rspamd should be installed
- Redis should be available if you intend to use it
- you should know the bind addresses and filtering choices you intend to use
- if you intend to use Brevo relay support, the Brevo prerequisite document should already be complete

## What the script changes

The apply script can:

- validate filtering inputs
- validate bind addresses and Redis settings
- create example Rspamd worker and Redis fragments
- create an antivirus example fragment
- create a Postfix milter fragment
- write a filtering summary file for review

This phase does not claim to fully deploy the live filtering stack or live relay stack by itself. It
prepares a clean, public-repo-friendly baseline for that deployment.

## Run the phase

From the project root:

```sh
doas ./scripts/phases/phase-07-apply.ksh
```

For deterministic config-only execution:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-07-apply.ksh
```

If you want the script to save prompted values back into config files, use:

```sh
doas env SAVE_CONFIG=yes ./scripts/phases/phase-07-apply.ksh
```

## Verify the phase

Run:

```sh
./scripts/phases/phase-07-verify.ksh
```

## What success looks like

A successful result means:

- filtering settings are valid
- required commands are available
- helper files were generated in `services/rspamd/` and `services/postfix/`
- the repo is ready for the next phase

## Troubleshooting

### The script says a bind address is invalid

Use a host and port pair such as:

- `127.0.0.1:11332`
- `127.0.0.1:11333`
- `127.0.0.1:11334`

### The script says the Redis port is invalid

Use a normal numeric TCP port such as `6379`.

### The script says the ClamAV toggle is invalid

Use:

- `yes`
- `no`

### The verify script warns that Rspamd tools are missing

Confirm the system has the expected Rspamd tools before continuing.

## Audience notes

### If you are new to self-hosting

Use the prompts, then review the generated helper files so you understand how
filtering and anti-abuse controls fit into the mail path.

### If you are already comfortable with OpenBSD mail systems

Pre-fill the config files, run the phase in noninteractive mode, and treat the
generated helper outputs as review artifacts before your live deployment step.

## Next phase

After Phase 07 succeeds, continue to the webmail and administration phase.


## Phase 02 runtime note

This phase now uses the shared core runtime renderer and installer. Review `docs/configuration/core-runtime-and-config-wiring.md`, then run `./scripts/install/render-core-runtime-configs.ksh` to stage the live operator runtime tree under `.work/runtime/rootfs/`. Use `services/generated/rootfs/` only as the tracked sanitized example reference.
