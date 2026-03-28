# Phase 06, TLS and certificate automation

## Purpose

Phase 06 prepares TLS and certificate automation guidance for the public
`openbsd-mailstack` project using a single certificate hostname model.

This phase is where the project defines how nginx, Postfix, Dovecot, and
OpenBSD `acme-client` should align on one public service hostname such as
`mail.example.com`.

It focuses on:

- validating the single certificate hostname model
- validating certificate file paths
- checking for required TLS and ACME commands
- generating public-safe TLS configuration fragments
- generating a reusable `acme-client` example stanza

## Who this phase is for

This phase is required for users who want the public project to provide a clean,
repeatable TLS model for:

- IMAP
- submission
- webmail
- administrative HTTPS endpoints

## Information you need before starting

You should have:

- a valid `MAIL_HOSTNAME`
- a valid `PRIMARY_DOMAIN`
- a valid `TLS_CERT_MODE`, normally `single_hostname`
- a valid `TLS_CERT_FQDN`, normally the same as `MAIL_HOSTNAME`
- a valid full chain certificate path
- a valid private key path
- an administrator email address

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

## Public TLS model

This public repo uses one service hostname for certificate identity.

Example:

```sh
MAIL_HOSTNAME="mail.example.com"
TLS_CERT_MODE="single_hostname"
TLS_CERT_FQDN="mail.example.com"
```

Hosted domains can still be:

```sh
DOMAINS="example.com example.net example.org"
```

In that model:

- one certificate secures the public mail and web endpoint
- multiple hosted domains still work behind that endpoint
- docs and fragments remain simple and consistent

## Preconditions

Before running this phase:

- Phase 00 should be complete
- Phase 01 should be complete
- Phase 02 should be complete
- Phase 03 should be complete
- Phase 04 should be complete
- Phase 05 should be complete
- OpenBSD `acme-client` should be available
- you should know the certificate path values you intend to use

## What the script changes

The apply script can:

- validate hostname and certificate inputs
- validate the single hostname TLS model
- create example TLS fragments for nginx, Postfix, and Dovecot
- create an example `acme-client` stanza
- write a summary file for review

This phase does not claim to request or install a live certificate by itself. It
prepares a clean, public-repo-friendly baseline for that deployment.

## Run the phase

From the project root:

```sh
doas ./scripts/phases/phase-06-apply.ksh
```

For deterministic config-only execution:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-06-apply.ksh
```

If you want the script to save prompted values back into config files, use:

```sh
doas env SAVE_CONFIG=yes ./scripts/phases/phase-06-apply.ksh
```

## Verify the phase

Run:

```sh
./scripts/phases/phase-06-verify.ksh
```

## What success looks like

A successful result means:

- the TLS hostname settings are valid
- the certificate path values are valid
- required commands are available
- helper files were generated in `services/nginx/`, `services/postfix/`, and
  `services/dovecot/`
- the repo is ready for the next phase

## Troubleshooting

### The script says the certificate hostname is invalid

Use a normal hostname such as `mail.example.com`. Do not use raw IP addresses.

### The script says TLS_CERT_MODE is invalid

For the public project baseline, use:

- `single_hostname`

### The script says a certificate path is invalid

Use absolute filesystem paths, for example:

- `/etc/ssl/mail.example.com.fullchain.pem`
- `/etc/ssl/private/mail.example.com.key`

### The verify script warns that acme-client is missing

Confirm the system is OpenBSD and that `acme-client` is available before
continuing.

## Audience notes

### If you are new to self-hosting

Use the prompts, then review the generated helper files so you understand how
all services share one certificate hostname.

### If you are already comfortable with OpenBSD mail systems

Pre-fill the config files, run the phase in noninteractive mode, and treat the
generated helper outputs as review artifacts before your live deployment step.

## Next phase

After Phase 06 succeeds, continue to the filtering and anti-abuse phase, where
mail inspection and scoring controls are prepared.
