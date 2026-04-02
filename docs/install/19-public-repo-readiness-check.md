# Public Repo Readiness Check

This checklist confirms that a new operator can work from the public repository alone, without needing private repo material for the public-safe baseline.

## A. Discovery path

A new operator should be able to discover:

- prerequisites and provider onboarding
- local operator input layout
- install order
- QEMU validation path
- production deployment sequence
- backup and restore path
- monitoring and maintenance path
- security hardening and runtime secret layout path

The main navigation documents for that are:

- [README](../../README.md)
- [Documentation map](../README.md)
- [Install guide](README.md)
- [Phase crosswalk](../phases/phase-crosswalk.md)

## B. Core public-safe assets

The repository should contain tracked assets for:

- core mail runtime templates
- staged rendered examples
- backup and DR helpers
- monitoring and maintenance helpers
- PF, WireGuard, DNS, and DDNS helpers
- Suricata, Brevo, SOGo, and SBOM optional layers
- `doas` and SSH hardening helpers
- host-local runtime secret layout helpers

## C. Documentation consistency

The repository should also satisfy these documentation conditions:

- README and install docs describe the same operator path
- phase docs match the actual scripts and service assets present
- no document still implies private assets were published when they were not
- navigation documents point to the current public-safe baseline, not an earlier lighter state

## D. Repository semantic integrity

A ready public repo should also be able to prove more than simple file presence.

At minimum, the public checks should validate:

- phase apply and verify coverage through Phase 17
- shell syntax for repo automation when `ksh` is available locally
- Python syntax for tracked Python helpers when a Python interpreter is available locally
- the absence of unresolved `__PLACEHOLDER__` tokens in concrete generated examples
- the continued use of gitignored `.work/` paths for live operator-generated outputs
- essential service wiring patterns in tracked sanitized examples and live render trees

The current repo-side semantic verifier is:

```sh
./scripts/verify/verify-repo-semantic-integrity.ksh
```

The current rendered config verifier is:

```sh
./scripts/verify/verify-rendered-config-integrity.ksh
```


## E. Automated public repo gates

The repository now includes a public CI workflow for repo-only validation. That workflow should be able to run without private inputs or a live OpenBSD host.

The local mirror of that workflow is:

```sh
./scripts/verify/run-repo-ci-gates.ksh
```

It should be able to:

- create temporary example-backed operator inputs
- render live runtime trees into temporary gitignored paths
- run repo semantic integrity checks
- exercise the public-safe render and phase surfaces that are valid to prove in CI

## F. Intentional boundaries

The following are still intentionally private:

- live production evidence
- encrypted DR payloads and restore archives
- real secrets, PATs, API tokens, and private keys
- site-specific control-plane doctrine

## G. Final operator reality

The public repository is considered ready when the remaining work is local operator population of:

- domains and hostnames
- network and exposure values
- provider accounts and API keys
- host-local runtime secret files
- final hardening choices

## Documentation integrity

The repo readiness surface now includes a dedicated documentation checker:

```sh
./scripts/verify/verify-documentation-integrity.ksh
```

This verifies local markdown links and documented repo file paths, while allowing explicitly local or generated paths such as `.work/`, `.local` files, and installer build outputs.
