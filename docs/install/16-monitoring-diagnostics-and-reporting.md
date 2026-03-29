# Monitoring, diagnostics, logging, and reporting baseline

## Purpose

This document explains how to turn the public monitoring and diagnostics layer into a usable operator baseline on an OpenBSD host.

It covers:

- the monitoring operator input model
- rendering the public-safe templates
- installing the monitoring assets on a host
- wiring cron and log rotation
- running the first monitoring cycle
- reading the generated monitoring pages and reports

## Inputs

Use `config/monitoring.conf.example` as the starting point.

Important values include:

- `MONITORING_SERVER_NAME`
- `MONITORING_URL_PATH`
- `MONITORING_OUTPUT_ROOT`
- `MONITORING_SITE_ROOT`
- `MONITORING_DATA_ROOT`
- `MONITORING_RCCTL_SERVICES`
- `MONITORING_TCP_PORTS`
- `MONITORING_LOG_FILES`
- `MONITORING_REPORT_EMAIL`
- `MONITORING_PATCH_NGINX`
- `MONITORING_PATCH_NEWSYSLOG`
- `MONITORING_INSTALL_CRON_SNIPPET`
- `MONITORING_PATCH_ROOT_CRONTAB`

Recommended placement:

- `config/local/monitoring.conf`
- `~/.config/openbsd-mailstack/monitoring.conf`
- `/root/.config/openbsd-mailstack/monitoring.conf`

## Render the public-safe baseline

From the repo root:

```sh
ksh ./scripts/phases/phase-14-apply.ksh
ksh ./scripts/phases/phase-14-verify.ksh
```

This produces repo-local rendered examples under:

- `services/generated/rootfs/etc/nginx/templates/openbsd-mailstack-ops-monitor.locations.tmpl`
- `services/generated/rootfs/etc/newsyslog.phase14-monitoring.conf`
- `services/generated/rootfs/etc/rspamd/local.d/logging.inc`
- `services/generated/rootfs/usr/local/share/examples/openbsd-mailstack-monitoring/root.cron.fragment`

## Install the host assets

Dry run first:

```sh
doas ksh ./scripts/install/install-monitoring-assets.ksh --dry-run
```

Then apply:

```sh
doas ksh ./scripts/install/install-monitoring-assets.ksh --apply
```

The installer stages:

- runtime monitoring scripts under `/usr/local/libexec/openbsd-mailstack/monitoring/`
- operator wrappers under `/usr/local/sbin/`
- rendered examples under `/usr/local/share/examples/openbsd-mailstack-monitoring/`
- optionally an nginx location template
- optionally a managed `newsyslog` block
- optionally a cron snippet or root crontab patch

## First run

Run the wrapper once:

```sh
doas /usr/local/sbin/openbsd-mailstack-monitoring-run
```

Expected outputs:

- `${MONITORING_DATA_ROOT}/latest.kv`
- `${MONITORING_DATA_ROOT}/latest.json`
- `${MONITORING_DATA_ROOT}/log-summary.txt`
- `${MONITORING_SITE_ROOT}/index.html`
- `${MONITORING_SITE_ROOT}/services.html`
- `${MONITORING_SITE_ROOT}/logs.html`
- `${MONITORING_SITE_ROOT}/changes.html`

## Daily report example

Generate an HTML report directly:

```sh
doas /usr/local/sbin/openbsd-mailstack-mail-health-report --stdout > /tmp/mail-health-report.html
```

Or run the generic reporting wrapper:

```sh
doas env MAIL_TO=ops@example.com MAIL_SUBJECT_PREFIX="[openbsd-mailstack monitoring]"   /usr/local/sbin/openbsd-mailstack-cron-html-report --label monitor-daily --   /usr/local/sbin/openbsd-mailstack-mail-health-report --stdout
```

## Notes on safety

- the monitoring site is static by design
- the default nginx template denies the `data/` path directly
- nothing in this phase publishes private evidence bundles, real secrets, or message bodies
- root crontab and live `newsyslog.conf` changes are opt-in, not default

## Suggested verification

```sh
ksh ./scripts/verify/verify-monitoring-assets.ksh
```

On a real host, also verify:

- `nginx -t`
- `newsyslog -n`
- the monitoring URL over the intended control-plane access path
- that the monitoring data directory is not directly exposed
