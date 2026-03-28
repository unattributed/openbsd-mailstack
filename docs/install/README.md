# Installation Prerequisites

## Purpose

This directory contains external prerequisites and install-side preparation documents that must be completed before the phase-driven build is started.

## Required order

1. `02-vultr-account-and-api-setup.md`
2. `03-brevo-account-and-relay-setup.md`

## Why this exists

Some parts of the mail stack depend on services and credentials that are external to the OpenBSD host itself. Those external dependencies must be created, delegated, and stored securely before later phases can be completed safely.

## Current external prerequisite coverage

### Vultr

The project uses Vultr as the authoritative DNS provider in the public baseline.

The Vultr prerequisite document covers:

- account creation
- domain DNS setup
- registrar nameserver delegation
- API key creation
- secure storage of the API key
- safe usage expectations for later DNS-related phases

### Brevo

The project uses Brevo as the public baseline smart relay and deliverability support layer.

The Brevo prerequisite document covers:

- account creation
- optional additional user and admin user creation
- API key and SMTP key creation
- secure storage of those credentials
- sender domain authentication expectations
- safe usage expectations for the filtering and relay phases

## Security rule

External provider credentials must never be committed to Git. Real values belong in a secure password manager, protected local secret files, or another secure operator-controlled secret store.
