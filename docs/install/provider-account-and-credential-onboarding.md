# Provider Account and Credential Onboarding

## Purpose

This document defines the operator account and credential onboarding model for
the public repo.

It does not store secrets. It tells the operator:

- which provider accounts are needed
- which ones are optional
- which files should hold local values
- where later scripts expect those values to come from

## Provider summary

| Capability | Provider account | Required now | Typical local file |
|---|---|---|---|
| Authoritative DNS and DDNS automation | Vultr | Required for the current public DNS and DDNS baseline | `config/local/providers/vultr.env` |
| Smart relay and deliverability support | Brevo | Optional | `config/local/providers/brevo.env` |
| External attachment or reputation analysis | VirusTotal | Optional | `config/local/providers/virustotal.env` |

## Related tracked inputs

Provider secrets stay out of Git, but tracked config still defines non-secret
behavior for later phases:

- `config/dns.conf.example`
- `config/ddns.conf.example`
- `config/network.conf.example`

## Recommended ignored local file targets

- `config/local/providers/vultr.env`
- `config/local/providers/brevo.env`
- `config/local/providers/virustotal.env`

## Preferred protected host-local paths

- `/root/.config/openbsd-mailstack/providers/vultr.env`
- `/root/.config/openbsd-mailstack/providers/brevo.env`
- `/root/.config/openbsd-mailstack/providers/virustotal.env`

## Failure model

Public scripts should fail clearly when a required value is missing.

The public pattern is:

- tracked examples document what is needed
- ignored local files hold real secrets
- the shared loader sources those files
- phase scripts prompt interactively if allowed
- noninteractive execution fails fast when a required value is absent
