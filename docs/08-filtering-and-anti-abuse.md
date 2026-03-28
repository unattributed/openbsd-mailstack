# Filtering and anti-abuse

## Purpose

This document explains how the public `openbsd-mailstack` project prepares mail
filtering, anti-abuse controls, and scoring guidance for the OpenBSD mail stack.

Phase 07 standardizes the public filtering model around:

- Postfix as the SMTP edge
- Rspamd as the content analysis and policy engine
- optional ClamAV integration for malware scanning
- Redis-backed caching where applicable
- a localhost-first service layout for filtering components

## Why this matters

A usable public mail stack needs a filtering model that is understandable,
repeatable, and safe to publish.

This phase prepares the repo for:

- spam scoring
- DKIM and DMARC-aware policy handling
- milter integration with Postfix
- anti-abuse controls that fit one mail host serving multiple domains
- malware scanning guidance without hardcoding production secrets

## Public filtering baseline

The public baseline is:

- one public mail hostname, such as `mail.example.com`
- one Postfix edge
- one local Rspamd deployment
- one or more hosted domains listed in `DOMAINS`
- optional local ClamAV integration

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

## What this phase expects from you

Before running Phase 07, you should know:

- the public mail hostname
- whether you want ClamAV enabled
- the bind addresses for Rspamd workers
- the Redis host and port to use
- whether you want Postfix milter integration fragments generated

These values can be placed in:

- `config/system.conf`

If they are missing, the apply script can prompt for them unless noninteractive
mode is enabled.

## What Phase 07 changes

The apply script is intentionally conservative. It prepares the repo workflow by:

- validating filtering-related settings
- validating bind addresses and Redis values
- confirming Rspamd and related commands exist
- generating public-safe Rspamd local.d examples
- generating a Postfix milter fragment example
- generating a filtering summary file for operator review

The generated files are helper artifacts. They are meant to guide later live
deployment on OpenBSD 7.8.

## Outputs created by Phase 07

The apply script can create these local project files:

- `services/rspamd/worker-proxy.inc.example.generated`
- `services/rspamd/worker-controller.inc.example.generated`
- `services/rspamd/redis.inc.example.generated`
- `services/rspamd/antivirus.conf.example.generated`
- `services/postfix/rspamd-milter.fragment.example.generated`
- `services/rspamd/filtering-summary.txt`

## Verification

The verify script checks:

- filtering settings are valid
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

After Phase 07 succeeds, the next logical phase is webmail and administration,
where Roundcube and web-facing management guidance are prepared.
