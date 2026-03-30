# QEMU-First Validation Path

## Purpose

This document gives a practical QEMU-first path for operators who want to validate the public repo before touching a real OpenBSD host.

## Why start here

The public repo now contains enough material to validate the first install and runtime path safely in a disposable VM.

That gives you a chance to confirm:

- your operator input files load correctly
- the live runtime tree renders correctly
- the public phase sequence runs in order
- the post-install validation path behaves as expected

## Recommended QEMU-first sequence

### 1. Prepare local inputs

Populate your operator input files first.

At minimum, confirm values exist for:

- `OPENBSD_VERSION`
- `MAIL_HOSTNAME`
- `PRIMARY_DOMAIN`
- `ADMIN_EMAIL`
- network and SQL values needed by the early phases

### 2. Build or boot the lab VM

Use the public QEMU assets under `maint/qemu/`.

For the initial walkthrough, start with:

```sh
ksh maint/qemu/fetch-openbsd-amd64-media.ksh --release 7.8
ksh maint/qemu/lab-openbsd78-build.ksh
```

### 3. Sync the repo into the VM

Use your preferred safe method, such as `scp`, `rsync`, or a Git clone inside the VM.

### 4. Render the live runtime tree inside the VM

```sh
./scripts/install/render-core-runtime-configs.ksh
```

This writes the live operator render into `.work/runtime/rootfs/` by default.

### 5. Run the first public baseline

Recommended first pass:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/install/run-phase-sequence.ksh --phase-start 0 --phase-end 8
```

When you want the wider baseline:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/install/run-phase-sequence.ksh --phase-start 0 --phase-end 10
```

### 6. Run post-install checks

```sh
./scripts/verify/run-post-install-checks.ksh
```

### 7. Record what you learned

Capture at least:

- any missing operator inputs
- any phase that required correction
- any rendered config you changed after inspection
- any service names or package names that differ on your target OpenBSD build

## Promotion gate before hardware

Move from QEMU to hardware only after:

- the phase sequence completes cleanly for your target phase range
- rendered configs look correct for your environment
- post-install checks are clean enough to explain every warning
- you understand which later phases are still optional or advanced

## What QEMU does not replace

QEMU validation does not replace:

- real DNS publication
- real certificate issuance against production names
- production backup and DR procedures
- real-world exposure review

Those still require deliberate operator decisions.
