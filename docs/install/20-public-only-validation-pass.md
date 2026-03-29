# Public-only validation pass

## Purpose

This document records the follow-up public-only validation pass after the remaining Roundcube hostname leak and staged generated file formatting issue were corrected.

## What was corrected

- removed the remaining live private hostname references from the public Roundcube template and the staged generated Roundcube config
- cleaned the staged generated rootfs files so they no longer contain accidental `-r -- ` line prefixes
- made `scripts/lib/common.ksh` write rendered template output with `printf`, which is safer for cross-shell rendering workflows
- added a single wrapper command for the final public-only validation pass

## Validation result

The public repo now passes the final repo-structure validation required for a new operator to use it as the public-safe baseline for building the same class of server as the private source repo, using operator-provided:

- domains and hostnames
- LAN, WireGuard, DNS, and DDNS values
- provider accounts and API keys
- local secret files and host-specific paths

## Exact command

Run this from the repo root:

```sh
./maint/final-public-validation-pass.ksh
```

That wrapper runs:

- `./scripts/verify/verify-public-repo-readiness.ksh`
- `./maint/design-authority-check.ksh --repo-only`

## Remaining boundaries

This validation pass does **not** prove a live OpenBSD deployment in this ChatGPT environment. It proves that the public repo is internally coherent, operator-addressable, and free of the known remaining private hostname leak in tracked public content.

The remaining non-public or partially automated areas are still:

- live production secrets, mailbox data, and restore payloads
- site-specific control-plane policy and incident evidence
- phases 15 and 16, which remain more documentation-led than automation-led
