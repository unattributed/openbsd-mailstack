# Project Architecture and Flow

## Purpose

This document explains how `openbsd-mailstack` is organized and how an operator is expected to move through the project.

## High-level model

The project is split into four practical layers:

1. install prerequisites
2. phase-driven build and verification
3. operations, backup, and recovery
4. lab and automation support

## Layer 1, install prerequisites

The install prerequisite documents cover services and credentials that are external to the OpenBSD host itself.

Current external prerequisites:

- Vultr for DNS
- Brevo for relay and deliverability support
- VirusTotal for optional external reputation and attachment analysis
- protected local provider secret files under `/root/.config/`

These are documented under `docs/install/`.

## Layer 2, phase-driven build

The phase system is the core of the project.

Each phase is expected to provide:

- a phase narrative document
- an apply script
- a verify script

The operator should run phases in order unless they already understand the dependencies and intentionally diverge.

## Layer 3, operations and recovery

The later public phases move beyond installation and into:

- operations
- resilience
- backup
- disaster recovery
- monitoring
- authentication hardening
- secret and key material handling

This is what makes the project a platform framework rather than a one-time install script.

## Layer 4, lab and automation support

The repo also supports two non-production usage modes:

- QEMU lab testing
- autonomous OpenBSD installer generation

These exist so the operator can validate the project without immediately depending on dedicated hardware or manual repetitive install steps.

## Typical operator flow

### Path A, direct host deployment

1. complete prerequisite docs
2. prepare config files
3. run Phase 00
4. continue phase-by-phase
5. verify after every phase
6. complete operations and recovery phases

### Path B, QEMU lab validation

1. complete prerequisite docs relevant to the test
2. build the QEMU lab VM
3. sync the repo into the VM
4. run selected phases
5. review generated reports
6. adjust before applying to a real host

### Path C, autonomous installer path

1. build a local installer profile
2. render the installer pack
3. serve it over HTTP
4. use OpenBSD autoinstall
5. bootstrap into the repo
6. continue with phases or guided workflows

## Design rules

The public repo should follow these rules:

- no live secrets in Git
- no private keys in Git
- no customer-specific state in Git
- no hardcoded operator identity like `foo`
- no hardcoded operator home path like `/home/foo`
- prefer example files and local runtime injection

## Why this matters

This structure allows the same public project to support:

- careful manual operators
- VM-based validation
- reproducible autonomous installs
- later private DR and site-specific extensions

That is the intended architecture of `openbsd-mailstack`.
