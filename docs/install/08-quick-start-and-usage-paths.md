# Quick Start and Usage Paths

## Purpose

This document helps a new operator decide how to begin using `openbsd-mailstack`.

## Before anything else

Complete:

- [Vultr account and API setup](02-vultr-account-and-api-setup.md)
- [Brevo account and relay setup](03-brevo-account-and-relay-setup.md)
- [VirusTotal API setup](04-virustotal-api-setup.md)
- [Local provider secret file layout](05-local-provider-secret-file-layout.md)
- [Install order and phase sequence](09-install-order-and-phase-sequence.md)

After that, choose one of the paths below.

## Path A, direct host path

Choose this if you already have OpenBSD hardware or a target host prepared.

### Recommended sequence

1. review [Architecture and flow](../architecture/01-project-architecture-and-flow.md)
2. review the config examples under `config/`
3. render the core runtime with `./scripts/install/render-core-runtime-configs.ksh`
4. review [First production deployment sequence](11-first-production-deployment-sequence.md)
5. run phases in order, typically through Phase 10 for the first public baseline
6. run `./scripts/verify/run-post-install-checks.ksh`

### Best for

- experienced OpenBSD operators
- users with target hardware already available
- users who want deliberate manual control

## Path B, QEMU lab path

Choose this if you want to learn and test without dedicated hardware.

### Recommended sequence

1. review [QEMU lab and VM testing](06-qemu-lab-and-vm-testing.md)
2. review [QEMU-first validation path](10-qemu-first-validation-path.md)
3. configure the lab under `maint/qemu/`
4. fetch OpenBSD media
5. build the lab VM
6. run the public phase sequence inside the VM
7. run post-install checks and capture what you learned before touching real hardware

### Best for

- new operators
- users validating documentation
- users testing changes before real deployment

## Path C, autonomous installer path

Choose this if you want a reusable OpenBSD autoinstall pack.

### Recommended sequence

1. review [OpenBSD autonomous installer](07-openbsd-autonomous-installer.md)
2. run the guided profile builder
3. render the installer pack
4. serve it locally over HTTP
5. run OpenBSD autoinstall
6. continue with repo-driven phase application
7. follow the same post-install checks and operator workflows as the other paths

### Best for

- repeatable installs
- lab reuse
- hardware rollout preparation
- operators replacing ad hoc install notes

## Minimum practical starting point

If you are unsure, the safest starting point is:

1. complete prerequisites
2. use the QEMU lab path
3. run Phase 00 through Phase 08 in the VM
4. add Phase 09 and Phase 10 when you are ready to test the wider public baseline
5. review the results with `./scripts/verify/run-post-install-checks.ksh`
6. then decide whether to move to hardware or the autonomous installer path

## What not to do

Do not:

- place live provider secrets in tracked files
- skip verification because a phase appears to finish successfully
- assume the public repo contains private DR material
- assume later private-repo behaviors are all already published here
- install staged configs onto a production host before reviewing the rendered tree

## Related documents

- [Top-level README](../../README.md)
- [Documentation map](../README.md)
- [Architecture and flow](../architecture/01-project-architecture-and-flow.md)
- [QEMU lab and VM testing](06-qemu-lab-and-vm-testing.md)
- [OpenBSD autonomous installer](07-openbsd-autonomous-installer.md)
- [Install order and phase sequence](09-install-order-and-phase-sequence.md)
- [First production deployment sequence](11-first-production-deployment-sequence.md)
- [Post-install checks](12-post-install-checks.md)
- [Security hardening and runtime secrets](21-security-hardening-and-runtime-secrets.md)
