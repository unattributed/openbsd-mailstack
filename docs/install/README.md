# Installation Prerequisites

## Purpose

This directory contains external prerequisites and install-side preparation documents that should be completed before the phase-driven build is started.

## Recommended order

1. `02-vultr-account-and-api-setup.md`
2. `03-brevo-account-and-relay-setup.md`
3. `04-virustotal-api-setup.md`
4. `05-local-provider-secret-file-layout.md`

## Optional operator path

For users who want to develop, test, and rehearse the project without dedicated hardware, use:

- `06-qemu-lab-and-vm-testing.md`

## Why this exists

Some parts of the mail stack depend on services and credentials that are external to the OpenBSD host itself. Those external dependencies should be created, delegated, and stored securely before later phases are completed.

## Current external prerequisite coverage

### Vultr

The public baseline uses Vultr as the authoritative DNS provider.

### Brevo

The public baseline uses Brevo as a smart-relay and deliverability support layer when direct self-hosted outbound delivery is not sufficient.

### VirusTotal

The public baseline uses VirusTotal as an optional external reputation and attachment analysis layer.

### Local provider secret files

The public baseline prefers protected root-owned local secret files under `/root/.config/` for provider credentials and similar sensitive operator data.

### QEMU lab testing

The public baseline now includes a QEMU lab layer under `maint/qemu/` for repeatable OpenBSD VM install, bootstrap, and phase execution testing.

## Security rule

External provider credentials must never be committed to Git. Real values belong in a secure password manager, protected local secret files, or another secure operator-controlled secret store.
