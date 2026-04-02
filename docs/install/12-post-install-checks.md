# Post-Install Checks

## Purpose

This document explains the public post-install validation path that should be run after you install the rendered runtime tree or after you complete a new phase sequence on a target OpenBSD host.

## Main script

Use:

- `scripts/verify/run-post-install-checks.ksh`

This script is designed to be public-safe and non-destructive.

## What it checks

The script can validate:

- presence of core repo assets
- presence of rendered runtime artifacts
- presence of required Postfix `hash:` map databases for relay credentials and TLS policy
- syntax and semantic integrity of repo-side shell and Python automation when the local toolchain is available
- presence of key installed config files on an OpenBSD host
- service status for known rcctl services when running on OpenBSD
- host-side semantic config checks such as `postfix check`, `nginx -t`, `doveconf -n`, `rspamadm configtest`, and PHP linting when the required commands are available
- basic operator input validity when values are present

## Recommended usage

### Full check

Use this after a real deployment or a serious QEMU validation run:

```sh
./scripts/verify/run-post-install-checks.ksh
```

### Repo-only check

Use this when you are reviewing the repo state from a workstation:

```sh
./scripts/verify/run-post-install-checks.ksh --repo-only
```

### Host-only check

Use this when you only want live host checks on OpenBSD:

```sh
./scripts/verify/run-post-install-checks.ksh --host-only
```

## Follow-on checks

After the post-install checks, it is reasonable to run:

```sh
./scripts/verify/verify-core-runtime-assets.ksh
./scripts/verify/verify-repo-semantic-integrity.ksh
./scripts/install/run-phase-sequence.ksh --phase-start 0 --phase-end 17 --verify-only
```

## Interpreting results

- `PASS` means the check succeeded as expected.
- `WARN` means the check could not be fully confirmed because a dependency, optional tool, or host service was not available.
- `FAIL` means the public baseline is not yet consistent enough for confident promotion.

## What this script intentionally does not do

The post-install checker does not:

- mutate host state
- create secrets
- publish DNS
- issue certificates
- claim private parity where it does not exist
