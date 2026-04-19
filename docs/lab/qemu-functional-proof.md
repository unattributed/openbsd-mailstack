# QEMU Functional Proof, lab-only

## Purpose

This document defines a narrow but useful proof target for `openbsd-mailstack`.

The objective is not internet-wide deliverability, production certificate issuance,
or public DNS publication. The objective is to prove that the project methods can
create a coherent and functional OpenBSD mail lab inside QEMU from a fresh VM.

## What this proof should demonstrate

A successful run should prove all of the following.

1. a fresh OpenBSD VM can be installed in QEMU
2. the repo can stage and install runtime configuration
3. the required mail packages can be installed on the guest
4. the guest can be seeded with synthetic mail domains, mailboxes, TLS, and DKIM
5. the core services can start and expose their expected listeners
6. SMTP, IMAP, HTTPS, SQL wiring, and maildir state can be checked locally

## Scope boundaries

This proof does not claim any of the following.

- public MX reachability
- real ACME issuance
- public DNS correctness
- public deliverability reputation
- complete greenfield PostfixAdmin deployment

## Recommended lab identities

Use reserved domains and addresses only.

- host: `mail.example.com`
- domains: `example.com`, `example.net`, `example.org`
- sample mailboxes:
  - `postmaster@example.com`
  - `abuse@example.com`
  - `admin@example.net`

## Repository placement

Copy the example lab config files into an ignored local overlay before use.

Example:

```sh
mkdir -p config/local/lab-qemu
cp config/examples/lab-qemu/system.conf.example config/local/lab-qemu/system.conf
cp config/examples/lab-qemu/network.conf.example config/local/lab-qemu/network.conf
cp config/examples/lab-qemu/domains.conf.example config/local/lab-qemu/domains.conf
cp config/examples/lab-qemu/secrets.conf.example config/local/lab-qemu/secrets.conf
```

The runner in this bundle is written so that it can also create a guest-local
copy of those files under `/home/foo/openbsd-mailstack/config/local/lab-qemu/`.

## Expected sequence

### 1. Validate repo assets

```sh
./scripts/verify/verify-lab-assets.ksh
./scripts/verify/verify-autonomous-installer-assets.ksh
./scripts/verify/verify-core-runtime-assets.ksh
```

### 2. Build the VM

Use the existing QEMU and autonomous installer flow already present in the repo.

### 3. Install package baseline inside the guest

Run:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 \
  OPENBSD_MAILSTACK_INPUT_ROOT=/home/foo/openbsd-mailstack/config/local/lab-qemu \
  ksh scripts/bootstrap/install-mailstack-packages.ksh
```

### 4. Render and install runtime config

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 \
  OPENBSD_MAILSTACK_INPUT_ROOT=/home/foo/openbsd-mailstack/config/local/lab-qemu \
  ksh scripts/install/run-phase-sequence.ksh --phase-start 0 --phase-end 8

doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 \
  OPENBSD_MAILSTACK_INPUT_ROOT=/home/foo/openbsd-mailstack/config/local/lab-qemu \
  ksh scripts/install/install-core-runtime-configs.ksh
```

### 5. Seed synthetic lab state

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 \
  OPENBSD_MAILSTACK_INPUT_ROOT=/home/foo/openbsd-mailstack/config/local/lab-qemu \
  ksh scripts/bootstrap/seed-lab-runtime-state.ksh --apply
```

### 6. Run functional verification

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 \
  OPENBSD_MAILSTACK_INPUT_ROOT=/home/foo/openbsd-mailstack/config/local/lab-qemu \
  ksh scripts/verify/verify-functional-mail-lab.ksh
```

## Minimum pass criteria

The proof should be considered successful only if all of the following are true.

- Postfix is running and `postfix check` passes
- Dovecot is running and TLS IMAP accepts a local connection
- MariaDB is running and the expected mailbox rows exist
- nginx is running and HTTPS answers for the lab host header
- `/var/vmail` contains the seeded sample mailboxes
- DKIM key files exist for each lab domain
- the repo host integrity verifier passes without fatal findings

## Current known limit

The public repo has config templates for PostfixAdmin but does not currently ship
an autonomous, public-safe PostfixAdmin application bootstrap. This proof bundle
therefore treats PostfixAdmin as optional for the first lab pass.
