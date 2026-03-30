# First Production Deployment Sequence

## Purpose

This document defines the first production deployment sequence for the public repo after the operator has validated the design in QEMU or has otherwise reviewed the live runtime tree carefully.

## Scope

This sequence aims for the first broader public baseline, usually Phase 00 through Phase 10.

It does not claim full private parity. It gives you the safest public order for what is already available.

## Before you start

You should already have:

- completed the prerequisite docs under `docs/install/`
- prepared real operator input files outside tracked Git content
- rendered the runtime tree at least once
- reviewed the QEMU path, or consciously decided to accept the extra risk of moving directly to hardware

## Recommended production sequence

### 1. Prepare the OpenBSD host

Confirm the host has:

- OpenBSD 7.8
- network connectivity
- your administrative access model
- the local repo checkout

### 2. Render the runtime tree from the repo

```sh
./scripts/install/render-core-runtime-configs.ksh
```

### 3. Review the live runtime tree

Inspect at least:

- `.work/runtime/rootfs/etc/postfix/`
- `.work/runtime/rootfs/etc/dovecot/`
- `.work/runtime/rootfs/etc/nginx/`
- `.work/runtime/rootfs/etc/rspamd/`
- `.work/runtime/rootfs/var/www/postfixadmin/`

Use `services/generated/rootfs/` only as the tracked sanitized example reference.

### 4. Run the public phase sequence

Recommended first production baseline:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/install/run-phase-sequence.ksh --phase-start 0 --phase-end 10
```

### 5. Stage the rendered tree into a review location

Recommended dry-run style install step:

```sh
doas ./scripts/install/install-core-runtime-configs.ksh --target-root /tmp/openbsd-mailstack-staging
```

Review the staged result under `/tmp/openbsd-mailstack-staging` before writing to `/`. Confirm that `/tmp/openbsd-mailstack-staging/etc/postfix/sasl_passwd.db` and `/tmp/openbsd-mailstack-staging/etc/postfix/tls_policy.db` are present.

### 6. Install onto the live host root

Only after review:

```sh
doas ./scripts/install/install-core-runtime-configs.ksh
```

### 7. Run post-install checks

```sh
./scripts/verify/run-post-install-checks.ksh
```

### 8. Start the daily and weekly operator cadence

Daily review:

```sh
./scripts/ops/daily-operator-review.ksh
```

Weekly review:

```sh
./scripts/ops/weekly-operator-review.ksh
```

## Public-safe promotion gate

Treat the host as ready for broader use only after:

- the phase run is clean for your chosen phase range
- the rendered and installed configs match your operator inputs
- post-install checks are reviewed
- unresolved warnings are understood and documented

## What is still optional or advanced

The following areas remain optional or advanced in the current public repo:

- later backup and DR phases
- advanced monitoring and enforcement layers
- optional SOGo and deeper web-plane expansion
- parity for site-specific operational doctrine from the private repo
