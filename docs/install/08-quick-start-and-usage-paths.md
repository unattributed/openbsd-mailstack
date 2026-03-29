# Quick Start and Usage Paths

## Purpose

This document helps a new operator decide how to begin using `openbsd-mailstack`.

## Before anything else

Complete:

- `docs/install/02-vultr-account-and-api-setup.md`
- `docs/install/03-brevo-account-and-relay-setup.md`
- `docs/install/04-virustotal-api-setup.md`
- `docs/install/05-local-provider-secret-file-layout.md`

After that, choose one of the paths below.

## Path A, direct host path

Choose this if you already have OpenBSD hardware or a target host prepared.

### Recommended sequence

1. review `docs/architecture/01-project-architecture-and-flow.md`
2. review the config examples under `config/`
3. start with Phase 00
4. continue phase-by-phase
5. run verify after every apply step

### Best for

- experienced OpenBSD operators
- users with target hardware already available
- users who want deliberate manual control

## Path B, QEMU lab path

Choose this if you want to learn and test without dedicated hardware.

### Recommended sequence

1. review `docs/install/06-qemu-lab-and-vm-testing.md`
2. configure the lab under `maint/qemu/`
3. fetch OpenBSD media
4. build the lab VM
5. run Phase 00 inside the VM
6. continue with additional phases as needed

### Best for

- new operators
- users validating documentation
- users testing changes before real deployment

## Path C, autonomous installer path

Choose this if you want a reusable OpenBSD autoinstall pack.

### Recommended sequence

1. review `docs/install/07-openbsd-autonomous-installer.md`
2. run the guided profile builder
3. render the installer pack
4. serve it locally over HTTP
5. run OpenBSD autoinstall
6. continue with repo-driven phase application

### Best for

- repeatable installs
- lab reuse
- hardware rollout preparation
- operators replacing ad hoc install notes

## Minimum practical starting point

If you are unsure, the safest starting point is:

1. complete prerequisites
2. use the QEMU lab path
3. run Phase 00 through Phase 03 in the VM
4. review the results
5. then decide whether to move to hardware or the autonomous installer path

## What not to do

Do not:

- place live provider secrets in tracked files
- skip verification because a phase appears to finish successfully
- assume the public repo contains private DR material
- assume later private-repo behaviors are all already published here

## Related documents

- `README.md`
- `docs/architecture/01-project-architecture-and-flow.md`
- `docs/install/06-qemu-lab-and-vm-testing.md`
- `docs/install/07-openbsd-autonomous-installer.md`
