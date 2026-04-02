# Phase 17, advanced optional integrations and gap closures

## Purpose

Extend the public repo with the highest-value remaining public-safe assets from the private repo:

- Suricata
- optional Brevo webhook integration
- optional SOGo baseline
- SBOM workflows

## Inputs

- `config/suricata.conf` or higher-precedence equivalent
- `config/brevo-webhook.conf` or higher-precedence equivalent
- `config/sogo.conf` or higher-precedence equivalent
- `config/sbom.conf` or higher-precedence equivalent

## Outputs

- rendered live optional service assets under `.work/advanced/rootfs/`, separate from the live core runtime tree under `.work/runtime/rootfs/`
- SBOM runtime output directory under `.work/advanced/sbom/`
- advanced summary output under `.work/advanced/advanced-gap-summary.txt`

## Run

```sh
doas ./scripts/phases/phase-17-apply.ksh
```

Verify:

```sh
./scripts/phases/phase-17-verify.ksh
```
