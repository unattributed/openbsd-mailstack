# Monitoring, Diagnostics, Logging, and Reporting Assets

This directory now contains the higher-fidelity public-safe monitoring implementation for `/_ops/monitor/`.

The monitoring layer is built around a static OpenBSD-native site renderer and verifier, adapted from the private `openbsd-self-hosting` implementation and sanitized for public use.

## What it produces

When the runtime data sources are present, the monitoring layer renders:

- `index.html`
- `host.html`
- `network.html`
- `pf.html`
- `mail.html`
- `rspamd.html`
- `dovecot.html`
- `postfix.html`
- `web.html`
- `dns.html`
- `ids.html`
- `vpn.html`
- `storage.html`
- `backups.html`
- `agent.html`
- `changes.html`
- sparkline SVGs under `sparklines/`

## Primary entrypoints

- `scripts/ops/monitoring-collect.ksh`
- `scripts/ops/monitoring-render.ksh`
- `scripts/ops/monitoring-run.ksh`
- `scripts/verify/verify-monitoring-assets.ksh`
- `scripts/install/install-monitoring-assets.ksh`

## Installed host paths

The installer keeps the public wrapper names and also provides compatibility paths closer to the private implementation:

- `/usr/local/sbin/openbsd-mailstack-monitoring-run`
- `/usr/local/libexec/openbsd-mailstack/monitoring/`
- `/usr/local/libexec/obsd-monitor/`
- `/usr/local/share/examples/openbsd-mailstack-monitoring/root.cron.fragment`
- `/usr/local/share/examples/obsd-monitor/root.cron.fragment`

## Safety model

- live hostnames are replaced with operator-provided values
- the nginx template denies `/_ops/monitor/data/`
- the site remains static and cron-generated
- missing optional later-phase inputs surface as degraded or missing signals, not as hardcoded private assumptions
