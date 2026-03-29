# Install Order and Phase Sequence

## Purpose

This document defines the recommended install order for the first public `openbsd-mailstack` baseline.

It ties together the prerequisites, core runtime rendering, phase execution order, verification, and promotion decisions.

## What can now be done entirely from the public repo

A new operator can now do the following using only public-safe repo assets:

1. complete provider onboarding and local operator input setup
2. render the sanitized runtime tree under `services/generated/rootfs/`
3. test the install path in QEMU
4. run the public phase sequence through the first usable mail baseline
5. stage and install the rendered configs onto a target OpenBSD host
6. run post-install checks and basic day-2 operator reviews

## Recommended install order

### 1. Complete prerequisites

Read and complete, in order:

1. `docs/install/provider-account-and-credential-onboarding.md`
2. `docs/install/02-vultr-account-and-api-setup.md`
3. `docs/install/03-brevo-account-and-relay-setup.md`
4. `docs/install/04-virustotal-api-setup.md`
5. `docs/install/user-input-file-layout.md`
6. `docs/install/05-local-provider-secret-file-layout.md`

### 2. Create local operator input files

At minimum, prepare:

- `config/system.conf`
- `config/network.conf`
- `config/domains.conf`
- `config/secrets.conf`

Or place those values in a higher-precedence local input location documented in `docs/install/user-input-file-layout.md`.

### 3. Render the core runtime

From the repo root:

```sh
./scripts/install/render-core-runtime-configs.ksh
```

Review the staged tree under:

- `services/generated/rootfs/`

### 4. Choose validation path first

Recommended order:

1. QEMU lab first
2. direct OpenBSD host second
3. autonomous installer only after the lab or direct-host baseline is understood

### 5. Run phases in order

For the first public baseline, use the shared phase runner.

Mail runtime baseline:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/install/run-phase-sequence.ksh --phase-start 0 --phase-end 8
```

Wider public baseline:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/install/run-phase-sequence.ksh --phase-start 0 --phase-end 10
```

This executes each apply script in sequence and runs the matching verify script before advancing.

## Which phase range to use

### Phase 00 through Phase 03

Use this when you are validating the earliest config, SQL, and admin-path setup.

### Phase 00 through Phase 08

Use this when you want the first practical mail runtime and web access baseline.

### Phase 00 through Phase 10

Use this when you want the first broader public baseline, including DNS identity publishing guidance and operations scaffolding.

### Phase 11 and later

Treat these as optional or advanced until your early baseline is clean and you have reviewed the current public parity limits in `docs/project-status.md`.

## Install sequence on a real OpenBSD host

1. render the runtime tree
2. review staged output
3. run the phase sequence
4. install the rendered configs onto the host
5. run post-install checks
6. only then expose or depend on the host for wider use

See `docs/install/11-first-production-deployment-sequence.md` for the detailed host order.

## Notes on scope and honesty

This install order does not claim that every late private behavior has already been published. It defines the safest public order for what is currently available.
