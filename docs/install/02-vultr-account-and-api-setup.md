# Vultr Account, DNS, and API Setup

## Purpose

This document defines the required Vultr setup for the public DNS and DDNS
workflows shipped in `openbsd-mailstack`.

## Account and DNS setup

1. create the Vultr account
2. add each hosted domain to Vultr DNS
3. delegate the registrar nameservers to the Vultr nameservers
4. generate an API key for DNS automation

## Secret handling

The API key is a secret. Do not place it in tracked repo files.

Preferred ignored files:

- `config/local/providers/vultr.env`
- `~/.config/openbsd-mailstack/providers/vultr.env`
- `/root/.config/openbsd-mailstack/providers/vultr.env`

Supported legacy path:

- `/root/.config/vultr/api.env`

Example content:

```sh
VULTR_API_KEY="REDACTED"
VULTR_API_URL="https://api.vultr.com/v2"
```

Set file mode:

```sh
chmod 600 /root/.config/openbsd-mailstack/providers/vultr.env
```

## Related tracked config

Keep non-secret Vultr-related inputs in tracked examples and ignored local files:

- `config/dns.conf.example`
- `config/ddns.conf.example`
- `config/network.conf.example`

## Used by

The public repo uses Vultr values for:

- DNS publishing guidance in Phase 09
- split-DNS and identity rendering
- DDNS preview and optional live sync in Phase 07
