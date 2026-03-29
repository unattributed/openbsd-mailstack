# Monitoring and reporting baseline

## Purpose

Phase 14 now provides a real public-safe operational visibility baseline for `openbsd-mailstack`.

It is built around:

- static monitoring pages generated from local snapshots
- text and HTML diagnostics reports
- log summary generation
- optional cron scheduling
- optional nginx and newsyslog integration
- small auditable shell scripts instead of a heavyweight monitoring stack

## What is included

The public repo now includes:

- a monitoring operator input model in `config/monitoring.conf.example`
- monitoring and diagnostics helper libraries under `scripts/lib/`
- collection, rendering, reporting, and wrapper scripts under `scripts/ops/`
- install helpers under `scripts/install/`
- verification helpers under `scripts/verify/`
- generic maintenance wrappers under `maint/`
- an nginx monitoring location template under `services/nginx/`
- a monitoring newsyslog managed block under `services/system/`
- an example cron fragment under `services/monitoring/`
- rendered example assets under `services/generated/rootfs/`

## Baseline outputs

On a host, the monitoring layer can produce:

- `latest.kv` and `latest.json` snapshots
- a log summary text artifact
- static HTML pages for overview, host, network, PF, mail, Rspamd, Dovecot, Postfix, web, DNS, IDS, VPN, storage, backups, agent, and changes
- HTML report output suitable for email delivery
- JSON status artifacts from the cron reporting wrapper

## Design goals

The public monitoring baseline is designed to be:

- conservative
- OpenBSD-friendly
- easy to audit
- non-destructive by default
- useful without any private repo state

## What it does not claim

This phase does not claim full parity with the private monitoring estate.

It does not publish:

- private operational evidence bundles
- live production dashboards from the private repo
- private control-plane automation
- host-specific ticket or governance logic

## Next step

After this phase, the public repo has a practical diagnostics and visibility baseline. Future work can safely extend it with more advanced hardening, IDS, DNS, or SBOM reporting where those can be generalized.


## Native ops parity

The public repo now includes a higher-fidelity OpenBSD-native monitor implementation under the standard public monitoring entrypoints. See `docs/install/22-openbsd-native-ops-monitoring-site.md`.
