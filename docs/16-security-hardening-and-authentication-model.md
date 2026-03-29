# Security hardening and authentication model

## Purpose

This phase now publishes a runnable, public-safe hardening baseline for the two
most reusable host controls that were still mostly documentation-led:

- `doas` policy posture
- SSH daemon hardening during a maintenance window

It also keeps the authentication policy work grounded in what the public repo can
actually support for PostfixAdmin, Roundcube, IMAP, and submission.

## What is now automated

The public repo now includes tracked and reusable helpers for:

- baseline `doas` policy rendering and drift checks
- optional command-scoped `doas` policy rendering, apply, check, and rollback
- SSH hardening planning, apply, verify, and rollback
- SSH watchdog health checks for a hardened host
- rendered public-safe examples for `doas.conf` and `sshd_config`

The main helpers are:

- `maint/doas-policy-baseline-check.ksh`
- `maint/doas-policy-transition.ksh`
- `maint/ssh-hardening-window.ksh`
- `maint/sshd-watchdog.ksh`
- `scripts/phases/phase-15-apply.ksh`
- `scripts/phases/phase-15-verify.ksh`

## Authentication model

The public-safe baseline remains conservative:

- strong unique passwords are required
- web and admin surfaces remain VPN-only during the baseline deployment model
- Roundcube remains a practical first webmail interface
- Dovecot remains the IMAP and submission credential authority
- second-factor rollout is staged, not blindly promised for all mail clients

## Why this is still not a universal MFA phase

Traditional mail clients such as Thunderbird normally authenticate over IMAP and
submission with username and password. Universal TOTP enforcement at the mail
protocol layer is not a drop-in feature for standard clients.

The public repo therefore treats second factor as:

- realistic for web surfaces first
- optional and staged for administrative surfaces
- future design work for legacy client compatibility paths

## Inputs

This phase uses values from:

- `config/security.conf.example`
- `config/system.conf.example`
- `config/network.conf.example`

## Outputs

Phase 15 now renders public-safe examples under:

- `services/generated/rootfs/etc/examples/openbsd-mailstack/doas.conf.baseline`
- `services/generated/rootfs/etc/examples/openbsd-mailstack/doas.conf.command-scoped`
- `services/generated/rootfs/etc/examples/openbsd-mailstack/sshd_config.phase15`
- `services/generated/rootfs/etc/examples/openbsd-mailstack/authentication-policy.txt`
- `services/generated/rootfs/etc/examples/openbsd-mailstack/password-policy.txt`
- `services/generated/rootfs/etc/examples/openbsd-mailstack/second-factor-roadmap.txt`

## What remains intentionally out of scope

This public phase still does not publish:

- live `/etc/doas.conf` from a production host
- live `/etc/ssh/sshd_config` from a production host
- private identity-provider integrations
- operator-specific MFA infrastructure
- host-specific command overlays that would reveal a private automation estate

Those remain operator-supplied or private by design.
