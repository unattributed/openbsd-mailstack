# Advanced optional integrations and gap closures

## Scope

This install guide covers the public-safe optional assets added for:

- Suricata
- Brevo webhook ingestion
- SOGo
- SBOM and host inventory scanning

## Tracked examples

Review these first:

- `config/suricata.conf.example`
- `config/brevo-webhook.conf.example`
- `config/sogo.conf.example`
- `config/sbom.conf.example`

## Render staged assets

```sh
./scripts/install/render-advanced-gap-configs.ksh
```

Review staged output under:

- `services/generated/rootfs/etc/suricata/`
- `services/generated/rootfs/etc/nginx/templates/`
- `services/generated/rootfs/etc/sogo/`
- `services/generated/rootfs/usr/local/sbin/`
- `services/generated/sbom/`

## Install optional assets onto a host

Dry run first:

```sh
doas ./scripts/install/install-advanced-gap-assets.ksh --dry-run
```

Apply only after review:

```sh
doas ./scripts/install/install-advanced-gap-assets.ksh --apply
```

## Verify

```sh
./scripts/verify/verify-advanced-gap-assets.ksh
```

## Notes

- Suricata is public-safe IDS baseline only in this repo.
- Brevo webhook support is optional and stays loopback-only by default.
- SOGo remains optional and requires operator-provided DB values.
- SBOM mapped mode requires `curl` and `jq`, and may also require an NVD API key depending on your rate and confidence requirements.
