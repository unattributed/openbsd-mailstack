# Monitoring, diagnostics, and reporting workflow

## Purpose

This document gives the routine operator workflow for the public monitoring layer.

It assumes the host has already been brought through the public install path, and that the monitoring assets from Phase 14 are installed.

## Daily operator routine

1. run `openbsd-mailstack-monitoring-run`
2. review `index.html` for broad health
3. review `services.html` for unexpected service state changes
4. review `logs.html` for recent failures, rejects, or repeated warnings
5. review `changes.html` for drift between the last two snapshots
6. confirm backup freshness is still visible in the monitoring snapshot
7. send or archive the daily HTML report when required

## Useful commands

```sh
doas /usr/local/sbin/openbsd-mailstack-monitoring-run
cat /var/www/monitor/data/latest.kv
sed -n '1,120p' /var/www/monitor/data/log-summary.txt
doas /usr/local/sbin/openbsd-mailstack-mail-health-report --stdout > /tmp/mail-health-report.html
```

## Weekly operator routine

Add these checks to the normal weekly review:

- confirm log rotation is still working for the monitoring and reporting logs
- confirm cron is still running the monitoring wrapper at the expected cadence
- review whether the monitored service list still matches the host role
- review whether the monitored log set still matches the deployed service footprint
- review bayes learning posture if Rspamd bayes reporting is enabled

## Investigation model

When there is an incident:

1. run the monitoring wrapper immediately
2. capture the latest report and log summary
3. compare `changes.html` to the last known-good snapshot
4. decide whether the problem is service state, listener state, log evidence, or backup freshness
5. escalate into the relevant phase docs or service docs only after the operational snapshot is understood

## Boundaries

This public monitoring layer is intentionally conservative.

It does not:

- auto-remediate failures
- publish the raw data directory to the web
- expose private evidence bundles
- require external monitoring daemons or a Prometheus or Grafana stack

It is meant to be a simple, auditable, OpenBSD-friendly visibility layer that a new operator can adopt first.


## Rich monitor site

When the host provides the expected runtime signals, the monitor site now includes the broader drill-down pages from the OpenBSD-native ops monitor implementation. Review `host.html`, `network.html`, `pf.html`, `mail.html`, `ids.html`, and `agent.html` as part of deeper investigations.
