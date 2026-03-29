# Phase 15, security hardening and authentication model

## Purpose

Extend the public mail stack with real public-safe hardening artifacts for:

- `doas` policy review
- optional command-scoped `doas` rollout
- SSH maintenance-window hardening
- staged authentication policy outputs

## Inputs

- `config/security.conf.example`
- `config/system.conf.example`
- `config/network.conf.example`

## Outputs

- rendered `doas` baseline policy example
- rendered command-scoped `doas` policy example
- rendered SSH hardening example
- authentication policy and password policy artifacts
- second-factor roadmap
- phase summary

## Main helpers

- `maint/doas-policy-baseline-check.ksh`
- `maint/doas-policy-transition.ksh`
- `maint/ssh-hardening-window.ksh`
- `maint/sshd-watchdog.ksh`

## Run

```sh
./scripts/phases/phase-15-apply.ksh
```

Verify:

```sh
./scripts/phases/phase-15-verify.ksh
```
