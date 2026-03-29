# QEMU Lab Layer

## Purpose

This directory provides a reusable OpenBSD QEMU lab layer for `openbsd-mailstack`.

It exists so operators can:

- prototype safely
- validate phase behavior
- rehearse install and recovery flow
- test changes before using dedicated hardware

## Files

- `qemu-lab.conf.example`
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
- `lab-dr-restore-runner.ksh`

## Workflow summary

1. fetch OpenBSD media
2. create the VM disk
3. install OpenBSD
4. bootstrap SSH and doas
5. copy the repo into the VM
6. run phases inside the VM
7. collect and review reports
8. run a staged restore rehearsal with `lab-dr-restore-runner.ksh`

## Notes

This directory is public and reusable. It must never contain live secrets, private keys, or customer-specific state.
