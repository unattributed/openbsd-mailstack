# Provider Account and Credential Onboarding

## Purpose

This document defines the operator account and credential onboarding model for the public repo.

It does not store secrets. It tells the operator:

- which provider accounts are needed
- which ones are optional
- which files should hold their local values
- where later scripts expect those values to come from

## Provider summary

| Capability | Provider account | Required now | Typical local file |
|---|---|---|---|
| Authoritative DNS automation | Vultr, or equivalent DNS provider adapted by the operator | Required for automated DNS workflows | `config/local/providers/vultr.env` |
| Smart relay and deliverability support | Brevo | Optional | `config/local/providers/brevo.env` |
| External attachment or reputation analysis | VirusTotal | Optional | `config/local/providers/virustotal.env` |

The detailed provider-specific onboarding documents remain:

- `docs/install/02-vultr-account-and-api-setup.md`
- `docs/install/03-brevo-account-and-relay-setup.md`
- `docs/install/04-virustotal-api-setup.md`

## Operator onboarding workflow

1. create or verify the provider account
2. generate the required API key or SMTP credential
3. store the secret outside tracked repo content
4. populate one of the supported ignored local input files
5. verify file ownership and mode
6. run the relevant phase scripts

## Recommended local file targets

Preferred repo-local ignored paths:

- `config/local/providers/vultr.env`
- `config/local/providers/brevo.env`
- `config/local/providers/virustotal.env`

Preferred protected host-local paths:

- `/root/.config/openbsd-mailstack/providers/vultr.env`
- `/root/.config/openbsd-mailstack/providers/brevo.env`
- `/root/.config/openbsd-mailstack/providers/virustotal.env`

Supported legacy paths:

- `/root/.config/vultr/api.env`
- `/root/.config/brevo/brevo.env`
- `/root/.config/virustotal/vt.env`

## File permissions

For any file that contains secrets:

- owner should be `root`
- mode should be `0600`

Example:

```sh
chmod 600 /root/.config/openbsd-mailstack/providers/vultr.env
chmod 600 /root/.config/openbsd-mailstack/providers/brevo.env
chmod 600 /root/.config/openbsd-mailstack/providers/virustotal.env
```

## Example provider file set

Use the repo-safe examples under:

- `config/examples/providers/vultr.env.example`
- `config/examples/providers/brevo.env.example`
- `config/examples/providers/virustotal.env.example`

Copy them into ignored local paths and replace the placeholder values.

## Loader behavior

The shared loader in `scripts/lib/operator-inputs.ksh` checks these sources in order:

1. repo-local config files under `config/`
2. repo-local overlays under `config/local/`
3. host-local project files under `~/.config/openbsd-mailstack/`
4. host-local project files under `/root/.config/openbsd-mailstack/`
5. legacy provider paths under `/root/.config/{vultr,brevo,virustotal}/`
6. any extra files listed in `OPENBSD_MAILSTACK_EXTRA_INPUT_FILES`

That means provider credentials can be kept out of tracked repo files while still being available to later phase scripts.

## Failure model

Public scripts should fail clearly when a required value is missing.

The public pattern is:

- examples and docs describe what is needed
- ignored local files hold the real value
- the shared loader sources those files
- phase scripts prompt interactively if allowed
- noninteractive execution fails fast on missing required values

## Minimum onboarding checklist

- [ ] provider account created
- [ ] required credentials generated
- [ ] credentials stored outside tracked repo files
- [ ] ignored local input file created
- [ ] file permissions set correctly
- [ ] relevant phase script can read the required values
