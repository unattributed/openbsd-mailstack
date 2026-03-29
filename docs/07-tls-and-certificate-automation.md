# TLS and certificate automation

## Purpose

This document explains how the public `openbsd-mailstack` project standardizes
TLS for the mail and web stack using a single certificate hostname model.

The public baseline is:

- one service hostname, such as `mail.example.com`
- one TLS certificate centered on that hostname
- one or more hosted mail domains behind that same service endpoint

That means users can host mail for several domains while keeping the operational
TLS model simple and predictable.

## Public TLS baseline

Use this pattern:

```sh
MAIL_HOSTNAME="mail.example.com"
PRIMARY_DOMAIN="example.com"
DOMAINS="example.com example.net example.org"
TLS_CERT_MODE="single_hostname"
TLS_CERT_FQDN="mail.example.com"
```

In that model:

- the TLS certificate is issued for `mail.example.com`
- IMAP, submission, and webmail all use `mail.example.com`
- hosted domains can still be `example.com`, `example.net`, and `example.org`
- MX records for each domain can point to the same mail host

## Why this matters

This keeps the public project easier to deploy and document because it avoids:

- one certificate per hosted domain
- multiple public service hostnames
- unnecessary SNI complexity in the first public release

It also makes OpenBSD `acme-client` automation easier to explain and operate.

## What this phase expects from you

Before running Phase 06, you should know:

- the public mail hostname, such as `mail.example.com`
- the administrator email address
- the certificate FQDN, normally the same as `MAIL_HOSTNAME`
- the certificate file paths to use in later service fragments
- whether you will use OpenBSD `acme-client`

These values can be placed in:

- `config/system.conf`

If they are missing, the apply script can prompt for them unless noninteractive
mode is enabled.

## What Phase 06 changes

The apply script is intentionally conservative. It prepares the repo workflow by:

- validating TLS hostname settings
- validating certificate path settings
- confirming `acme-client` and related commands exist
- generating public-safe example fragments for nginx, Postfix, and Dovecot
- generating an example `acme-client.conf` stanza
- writing a TLS summary file for operator review

The generated files are helper artifacts. They are intended to guide later live
deployment on OpenBSD 7.8.

## Outputs created by Phase 06

The apply script can create these local project files:

- `services/nginx/tls-server.fragment.example.generated`
- `services/postfix/tls-main.cf.fragment.example.generated`
- `services/dovecot/tls.conf.fragment.example.generated`
- `services/nginx/acme-client.example.generated`
- `services/nginx/tls-summary.txt`

## Verification

The verify script checks:

- hostname and certificate settings are valid
- required commands exist
- generated helper files exist when expected

## Recommended usage

For experienced users:

- pre-fill the config files
- run the phase in noninteractive mode
- review the generated helper files before moving on

For newer users:

- run the script interactively
- answer the prompts carefully
- use the generated fragments as your implementation guide

## Next step

After Phase 06 succeeds, the next logical phase is mail filtering and content
inspection, where Rspamd and related scanning controls are prepared.


## Phase 02 runtime note

This phase now uses the shared core runtime renderer and installer. Review `docs/configuration/core-runtime-and-config-wiring.md`, then run `./scripts/install/render-core-runtime-configs.ksh` to stage sanitized service configs under `services/generated/rootfs/`.
