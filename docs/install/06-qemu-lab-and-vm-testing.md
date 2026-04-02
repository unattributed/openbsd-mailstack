# QEMU Lab and VM Testing

## Purpose

This document explains how to use the public QEMU lab layer to:

- test the project without dedicated hardware
- rehearse install and bootstrap flow
- run phases inside a disposable OpenBSD VM
- validate changes before applying them to a real host

## Scope

The QEMU lab layer is intended for:

- development
- experimentation
- regression rehearsal
- documentation validation
- operator training

It is not a replacement for production deployment planning.

## Directory layout

The public QEMU assets live under:

- `maint/qemu/`

## Supported workflow

The baseline flow is:

1. fetch official OpenBSD install media
2. create a QEMU disk image
3. run the unattended install helper
4. bootstrap SSH and doas access
5. sync the repo into the VM
6. run one or more phases inside the VM
7. review generated reports
8. run the public post-install checks before promoting anything to hardware

## Required host-side tools

Typical Linux workstation tools:

- `qemu-system-x86_64`
- `qemu-img`
- `expect`
- `ssh`
- `scp`
- `rsync`
- `curl`
- `signify` if you want local verification of downloaded OpenBSD media

## Suggested host layout

Examples only:

- `/home/foo/VMs/iso`
- `/home/foo/VMs/openbsd-mail/disk-lab.qcow2`

These defaults are used in the example scripts, but can be overridden with environment variables.

## Main scripts

- `fetch-openbsd-amd64-media.ksh`
- `lab-install.sh`
- `lab-install.expect`
- `lab-bootstrap.expect`
- `lab-ssh-bootstrap.expect`
- `lab-openbsd78-build.ksh`
- `lab-phase-runner.ksh`
- `lab-ssh-guard.ksh`
- `lab-vm-ssh.ksh`
- `vm-phase-report-runner.ksh`
- `qemu-lab.conf.example`

## Recommended first run

### 1. Review the example config

Copy the example to a local untracked file beside it, then adjust the local copy:

```sh
cp maint/qemu/qemu-lab.conf.example maint/qemu/qemu-lab.conf.local
```

`maint/qemu/qemu-lab.conf.local` is an operator-local file created by this step. It is intentionally not tracked in the repo.

### 2. Fetch OpenBSD media

```sh
ksh maint/qemu/fetch-openbsd-amd64-media.ksh --release 7.8
```

### 3. Build the lab VM

```sh
ksh maint/qemu/lab-openbsd78-build.ksh
```

### 4. Run the first public baseline inside the VM

Inside the VM, from the repo root, use either a narrow or wider path.

Narrow mail runtime baseline:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/install/run-phase-sequence.ksh --phase-start 0 --phase-end 8
```

Wider public baseline including DNS and operations scaffolding:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/install/run-phase-sequence.ksh --phase-start 0 --phase-end 10
```

### 5. Run post-install checks

```sh
./scripts/verify/run-post-install-checks.ksh
```

## Safety model

This lab layer is designed to be:

- disposable
- operator-driven
- non-production
- safe to reset and rebuild

Do not place live provider secrets into the tracked repository while using the lab.

## Next step

After the lab VM is working, continue with the phase-driven workflow as you would on a real host, but keep all provider secrets in protected local files only. When the VM path is stable, move to `docs/install/11-first-production-deployment-sequence.md`.
