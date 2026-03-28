# Installation Prerequisites

## Purpose

This directory contains external prerequisites and install-side preparation documents that should be completed before the phase-driven build is started.

## Recommended order

1. `02-vultr-account-and-api-setup.md`
2. `03-brevo-account-and-relay-setup.md`
3. `04-virustotal-api-setup.md`
4. `05-local-provider-secret-file-layout.md`

## Why this exists

Some parts of the mail stack depend on services and credentials that are external to the OpenBSD host itself. Those external dependencies should be created, delegated, and stored securely before later phases are completed.

## Current external prerequisite coverage

### Vultr

The public baseline uses Vultr as the authoritative DNS provider.

The Vultr prerequisite document covers:

- account creation
- domain DNS setup
- registrar nameserver delegation
- API key creation
- secure storage of the API key
- safe usage expectations for later DNS-related phases

### Brevo

The public baseline uses Brevo as a smart-relay and deliverability support layer when direct self-hosted outbound delivery is not sufficient.

The Brevo prerequisite document covers:

- account creation
- optional additional user and admin user creation
- API key and SMTP key creation
- secure storage of those credentials
- sender domain authentication expectations
- safe usage expectations for relay-related phases

### VirusTotal

The public baseline uses VirusTotal as an optional external reputation and attachment analysis layer.

The VirusTotal prerequisite document covers:

- account creation
- API key creation
- secure storage of the API key
- quota and privacy considerations
- safe usage expectations for malware or attachment analysis workflows

### Local provider secret files

The public baseline prefers protected root-owned local secret files under `/root/.config/` for provider credentials and similar sensitive operator data.

## Security rule

External provider credentials must never be committed to Git. Real values belong in a secure password manager, protected local secret files, or another secure operator-controlled secret store.
