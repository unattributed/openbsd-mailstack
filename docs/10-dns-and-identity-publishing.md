# DNS and identity publishing

## Purpose

This document explains how the public `openbsd-mailstack` project prepares DNS
and identity publishing for the mail platform.

Phase 09 standardizes the public identity model around:

- one public mail hostname, such as `mail.example.com`
- one or more hosted mail domains
- MX records for each hosted domain pointing to the same mail hostname
- per-domain SPF, DKIM, and DMARC publishing
- optional MTA-STS guidance

## Why this matters

A modern mail stack needs consistent identity records so other systems can:

- locate the mail host
- evaluate whether the host is authorized to send mail
- validate DKIM signatures
- enforce or monitor DMARC policy

This phase prepares the repo for:

- multi-domain DNS guidance
- per-domain DKIM planning
- per-domain policy publishing
- public-safe record generation artifacts

## Public identity baseline

Use this pattern:

```sh
MAIL_HOSTNAME="mail.example.com"
PRIMARY_DOMAIN="example.com"
DOMAINS="example.com example.net example.org"
DKIM_SELECTOR="mail"
MX_PRIORITY="10"
```

In that model:

- MX for each hosted domain points to `mail.example.com`
- the same public mail host serves all domains
- each hosted domain still gets its own DKIM record
- each hosted domain still gets its own SPF and DMARC record

## What this phase expects from you

Before running Phase 09, you should know:

- the public mail hostname
- the hosted domain list
- the DKIM selector to use
- the SPF policy text
- the DMARC policy text
- the MX priority you want to publish
- whether you want MTA-STS notes included

These values can be placed in:

- `config/system.conf`
- `config/domains.conf`

If they are missing, the apply script can prompt for them unless noninteractive
mode is enabled.

## What Phase 09 changes

The apply script is intentionally conservative. It prepares the repo workflow by:

- validating DNS identity settings
- validating hosted domains
- generating public-safe DNS record output for each hosted domain
- generating DKIM placeholder guidance per domain
- generating an identity summary for operator review

The generated files are helper artifacts. They are intended to guide later live
deployment with your DNS provider and DKIM key generation tooling.

## Outputs created by Phase 09

The apply script can create these local project files:

- `services/dns/zone-records.example.generated`
- `services/dns/mta-sts-notes.example.generated`
- `services/dns/identity-summary.txt`
- `services/dkim/dkim-records.example.generated`

## Verification

The verify script checks:

- domain and hostname settings are valid
- DNS identity values are present
- generated helper files exist when expected

## Recommended usage

For experienced users:

- pre-fill the config files
- run the phase in noninteractive mode
- review the generated helper files before moving on

For newer users:

- run the script interactively
- answer the prompts carefully
- use the generated DNS records as your implementation guide

## Next step

After Phase 09 succeeds, the next logical phase is operations and maintenance,
where backup, monitoring, and maintenance guidance can be refined for public use.
