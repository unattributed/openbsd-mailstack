# Phase 09, DNS and identity publishing

## Purpose

Phase 09 prepares DNS and identity publishing guidance for the public
`openbsd-mailstack` project.

This phase defines how hosted domains should publish:

- MX records
- SPF records
- DKIM records
- DMARC records
- optional MTA-STS notes

It uses the public baseline where one mail host identity serves one or more
hosted domains.

## Who this phase is for

This phase is required for users who want a complete identity publishing model
for:

- one hosted mail domain
- multiple hosted mail domains
- a shared mail hostname with per-domain policy publishing

## Information you need before starting

You should have:

- a valid `MAIL_HOSTNAME`
- a valid `PRIMARY_DOMAIN`
- a valid `DOMAINS` list
- a valid `DKIM_SELECTOR`
- a valid `SPF_POLICY`
- a valid `DMARC_POLICY`
- a valid `MX_PRIORITY`
- an optional `MTA_STS_MODE`

## How user customization works

This phase supports two ways to provide values.

### Method 1, configuration files

Recommended for repeatable deployments.

Edit:

- `config/system.conf`
- `config/domains.conf`

### Method 2, interactive prompts

If required values are missing, the apply script can prompt for them.

This is useful for first-time users, but config files remain the better long-term
option because they make later phases easier and more deterministic.

Do not edit the scripts themselves to change deployment values.

## Identity model

The public repo enforces this model:

- one `MAIL_HOSTNAME`, such as `mail.example.com`
- multiple hosted domains in `DOMAINS`
- each hosted domain publishes MX pointing to `MAIL_HOSTNAME`
- each hosted domain publishes its own SPF, DKIM, and DMARC

Example:

```sh
MAIL_HOSTNAME="mail.example.com"
DOMAINS="example.com example.net example.org"
DKIM_SELECTOR="mail"
MX_PRIORITY="10"
```

## Preconditions

Before running this phase:

- Phase 00 through Phase 08 should be complete
- the mail hostname should already be chosen
- the hosted domains should already be defined
- TLS hostname planning should already be complete

## What the script changes

The apply script can:

- validate DNS identity inputs
- validate domains and hostnames
- generate DNS record examples for all hosted domains
- generate DKIM placeholder records for all hosted domains
- write identity summary artifacts for review

This phase does not claim to publish live DNS automatically. It prepares a
clean, public-repo-friendly baseline for that deployment.

## Run the phase

From the project root:

```sh
doas ./scripts/phases/phase-09-apply.ksh
```

For deterministic config-only execution:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-09-apply.ksh
```

If you want the script to save prompted values back into config files, use:

```sh
doas env SAVE_CONFIG=yes ./scripts/phases/phase-09-apply.ksh
```

## Verify the phase

Run:

```sh
./scripts/phases/phase-09-verify.ksh
```

## What success looks like

A successful result means:

- DNS identity settings are valid
- generated DNS and DKIM helper files exist
- the repo is ready for further operations work

## Troubleshooting

### The script says a domain is invalid

Use normal DNS domains such as:

- `example.com`
- `example.net`

### The script says MX priority is invalid

Use a numeric priority such as:

- `10`

### The script says DKIM selector is invalid

Use a short label such as:

- `mail`
- `default`

### The verify script warns that generated files are missing

Run the apply phase first, then rerun the verify phase.

## Audience notes

### If you are new to self-hosting

Use the prompts, then review the generated DNS records carefully before adding
them to your registrar or DNS provider.

### If you are already comfortable with mail DNS

Pre-fill the config files, run the phase in noninteractive mode, and treat the
generated helper outputs as review artifacts before live publication.

## Next phase

After Phase 09 succeeds, continue to the public operations and maintenance phase.
