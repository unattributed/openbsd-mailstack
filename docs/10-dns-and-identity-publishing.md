# DNS and Identity Publishing

## Purpose

This document explains how the public repo handles DNS identity publishing,
split DNS, and optional dynamic DNS updates.

## Public baseline

The repo assumes:

- one public mail hostname, such as `mail.example.com`
- one or more hosted domains
- MX for each hosted domain pointing to the same mail hostname
- per-domain SPF, DKIM, and DMARC publishing
- optional MTA-STS guidance
- optional Vultr-backed DDNS updates for the public mail host

## Inputs

The public-safe input model is split intentionally:

- `config/system.conf` holds host identity values such as `MAIL_HOSTNAME`
- `config/domains.conf` holds the hosted domain list
- `config/dns.conf` holds policy values such as SPF, DMARC, and Unbound knobs
- `config/ddns.conf` holds DDNS behavior and non-secret provider metadata
- provider tokens remain in ignored files such as `config/local/providers/vultr.env`

## What Phase 09 now does

Phase 09 is still intentionally conservative, but it now maps to real public
tooling. It can:

- validate mail identity inputs
- generate DNS record guidance for each hosted domain
- render split-DNS and DDNS assets through the shared network exposure helper
- provide preview-level DDNS planning without forcing a live API change

## What remains outside the public repo

The public repo does not publish:

- real provider API tokens
- live zone IDs
- production DNS dumps
- real private WireGuard peers
