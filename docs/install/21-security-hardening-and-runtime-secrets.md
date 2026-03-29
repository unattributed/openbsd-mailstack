# Security Hardening and Runtime Secrets

## Goal

This document closes the last major public-safe operational gap that remained
lighter than the private repo.

It explains how to use the new public helpers for:

- `doas` policy review and optional command-scoped transition
- SSH maintenance-window hardening and rollback
- host-local runtime secret file layout and verification

## 1. Prepare local operator inputs

Copy and edit these tracked examples into ignored local files:

- `config/security.conf.example`
- `config/secrets-runtime.conf.example`

Suggested locations:

- `config/local/security.conf`
- `config/local/secrets-runtime.conf`
- `/root/.config/openbsd-mailstack/security.conf`
- `/root/.config/openbsd-mailstack/secrets-runtime.conf`

## 2. Render the public-safe examples

From the repo root:

```sh
./scripts/phases/phase-15-apply.ksh
./scripts/phases/phase-16-apply.ksh
```

Review the rendered files under:

- `services/generated/rootfs/etc/examples/openbsd-mailstack/`
- `services/generated/rootfs/etc/postfixadmin/`
- `services/generated/rootfs/etc/roundcube/`

## 3. Review the current and target `doas` posture

Render the broad baseline:

```sh
./maint/doas-policy-baseline-check.ksh --render
```

Render the optional command-scoped posture:

```sh
./maint/doas-policy-transition.ksh --render
```

If you are evaluating the command-scoped posture on an OpenBSD host, use a
maintenance window and the built-in backup and rollback path.

## 4. Review the SSH hardening plan

```sh
doas ./maint/ssh-hardening-window.ksh --plan
```

When ready, apply and verify during a maintenance window:

```sh
doas ./maint/ssh-hardening-window.ksh --apply
doas ./maint/ssh-hardening-window.ksh --verify
```

Rollback is built in:

```sh
doas ./maint/ssh-hardening-window.ksh --rollback
```

## 5. Prepare the host-local runtime secret layout

Review the layout:

```sh
./maint/runtime-secret-layout.ksh --plan
```

Create the directories on the host:

```sh
doas ./maint/runtime-secret-layout.ksh --install-dirs
```

Render safe stubs into a scratch directory for editing:

```sh
./maint/runtime-secret-layout.ksh --render-stubs /tmp/openbsd-mailstack-secret-stubs
```

## 6. Verify the tracked repo is still safe to publish

```sh
./maint/repo-secret-guard.ksh
```

## 7. Verify the phase assets

```sh
./scripts/phases/phase-15-verify.ksh
./scripts/phases/phase-16-verify.ksh
```

## Result

After this step, the public repo now provides runnable public-safe helpers for
hardening and host-local secret layout work. Operators still supply their own
identities, private keys, passwords, and provider credentials locally, which is
part of the design rather than a missing migration.
