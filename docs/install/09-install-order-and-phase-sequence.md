# Install Order and Phase Sequence

## Purpose

This document defines the recommended install order for the public `openbsd-mailstack` baseline.

It ties together prerequisites, core runtime rendering, phase execution order, verification, and promotion decisions.

## What can now be done entirely from the public repo

A new operator can now do the following using only public-safe repo assets:

1. complete provider onboarding and local operator input setup
2. render the live operator runtime tree under `.work/runtime/rootfs/`, while using `services/generated/rootfs/` as the sanitized example reference
3. test the install path in QEMU
4. run the public phase sequence through the first usable mail baseline
5. stage and install the rendered configs onto a target OpenBSD host, with the install helper rebuilding the required Postfix `hash:` maps
6. run post-install checks and operator workflows
7. extend the baseline with backup, monitoring, maintenance, hardening, runtime secrets, and optional advanced layers

## Recommended install order

### 1. Complete prerequisites

Read and complete, in order:

1. [Provider account and credential onboarding](provider-account-and-credential-onboarding.md)
2. [Vultr account and API setup](02-vultr-account-and-api-setup.md)
3. [Brevo account and relay setup](03-brevo-account-and-relay-setup.md)
4. [VirusTotal API setup](04-virustotal-api-setup.md)
5. [User input file layout](user-input-file-layout.md)
6. [Local provider secret file layout](05-local-provider-secret-file-layout.md)

### 2. Create local operator input files

At minimum, prepare:

- `config/system.conf`
- `config/network.conf`
- `config/domains.conf`
- `config/secrets.conf`

Or place those values in a higher-precedence local input location documented in [User input file layout](user-input-file-layout.md).

### 3. Render the core runtime

From the repo root:

```sh
./scripts/install/render-core-runtime-configs.ksh
```

Review the live operator tree under:

- `.work/runtime/rootfs/`

Use `services/generated/rootfs/` only as the tracked sanitized example tree. Live operator renders now stage under gitignored `.work/` paths by default, including `.work/runtime/rootfs/`, `.work/network-exposure/rootfs/`, `.work/identity/`, and `.work/advanced/`. The live rendered secret-bearing core runtime files under `.work/runtime/rootfs/` are forced to mode `0600`.

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

Extended public-safe operational baseline:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/install/run-phase-sequence.ksh --phase-start 0 --phase-end 17
```

This executes each apply script in sequence and runs the matching verify script before advancing.

Phases 02 through 08 still share the core runtime renderer, but they now emit targeted phase summaries and run phase-scoped verification for the specific assets that belong to each layer.

## Which phase range to use

### Phase 00 through Phase 03

Use this when you are validating the earliest config, SQL, and admin-path setup.

### Phase 00 through Phase 08

Use this when you want the first practical mail runtime and web access baseline.

### Phase 00 through Phase 10

Use this when you want the first broader public baseline, including DNS identity publishing guidance and operations scaffolding.

### Phase 11 through Phase 17

Use these after the early baseline is stable and you are ready to add:

- backup and DR
- monitoring and maintenance
- network exposure refinement
- security hardening and runtime secret layout
- optional advanced integrations

Review [Project status](../project-status.md) and [Phase crosswalk](../phases/phase-crosswalk.md) before promoting those layers to a real host.

## Install sequence on a real OpenBSD host

1. render the live runtime tree
2. review the live operator output under `.work/runtime/rootfs/`
3. run the phase sequence
4. install the rendered configs onto the host
5. run post-install checks
6. run the targeted public hardening validation pass
7. only then expose or depend on the host for wider use

See [First production deployment sequence](11-first-production-deployment-sequence.md) for the detailed host order.

## Notes on scope and honesty

This install order does not claim that every private behavior has already been published. It defines the safest public order for what is currently available in the public repository.
