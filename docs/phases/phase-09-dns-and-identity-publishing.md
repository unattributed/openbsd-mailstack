# Phase 09, DNS and identity publishing

## Goal

Validate domain identity settings and produce public-safe DNS guidance that
aligns with the rendered network layer.

## What Phase 09 now does

- validates `MAIL_HOSTNAME`, `PRIMARY_DOMAIN`, and `DOMAINS`
- generates DNS identity guidance files
- reuses the shared network exposure renderer so Unbound and DDNS assets stay aligned
- supports DDNS preview mode without requiring a live API change

## Inputs

- `config/system.conf`
- `config/domains.conf`
- `config/dns.conf`
- `config/ddns.conf`
- ignored Vultr provider files for any live API work
