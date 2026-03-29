# OpenBSD native ops monitoring site

## Purpose

This document explains the higher-fidelity `/_ops/monitor/` implementation now available in the public repo.

It is the public-safe parity path for the private `openbsd-native-ops` monitor implementation. It keeps the same general operating model:

- static HTML under `/var/www/monitor/site`
- snapshot and trend data under `/var/www/monitor/data`
- cron-driven collection, rendering, and verification
- control-plane ACLs through nginx
- no new external daemon stack

## Operator inputs

Start with `config/monitoring.conf.example`.

Important values for the native-ops monitor path:

- `MONITORING_SERVER_NAME`
- `MONITORING_HOST_IP`
- `MONITORING_URL_PATH`
- `MONITORING_OUTPUT_ROOT`
- `MONITORING_SITE_ROOT`
- `MONITORING_DATA_ROOT`
- `MONITORING_PF_JSON_ROOT`
- `MONITORING_PFSTAT_ROOT`
- `MONITORING_REPORT_EMAIL`
- `MONITORING_CHECK_HTTP`
- `MONITORING_PHASE14_FAST_PATH_CMD`

## Install path

Dry run first:

```sh
doas ksh ./scripts/install/install-monitoring-assets.ksh --dry-run
```

Then apply:

```sh
doas ksh ./scripts/install/install-monitoring-assets.ksh --apply
```

The installer now provisions:

- repo-style wrappers under `/usr/local/sbin/`
- runtime scripts under `/usr/local/libexec/openbsd-mailstack/monitoring/`
- compatibility paths under `/usr/local/libexec/obsd-monitor/`
- cron fragment examples under both:
  - `/usr/local/share/examples/openbsd-mailstack-monitoring/root.cron.fragment`
  - `/usr/local/share/examples/obsd-monitor/root.cron.fragment`

## First run

```sh
doas /usr/local/sbin/openbsd-mailstack-monitoring-run
```

Or, using the compatibility path:

```sh
doas /usr/local/libexec/obsd-monitor/obsd_monitor_run.ksh
```

## Expected site pages

After a successful run, the monitor site should include:

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

## Verification

```sh
doas /usr/local/sbin/openbsd-mailstack-monitoring-run
doas /usr/local/libexec/openbsd-mailstack/monitoring/verify-monitoring-assets.ksh
```

If HTTP checks are enabled:

- `/_ops/monitor/` should be reachable on the intended control-plane path
- `/_ops/monitor/data/` should return `403` or `404`

## Notes

This monitor implementation is still public-safe, not private-identical.

It does not publish:

- live private evidence bundles
- private queue execution artifacts
- private incident or governance ledgers beyond what can be rendered safely from public-side runtime data
