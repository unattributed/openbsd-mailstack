# Phase 14, monitoring and reporting baseline

## Purpose

Migrate the public-safe operational visibility layer so a new operator can actually inspect, report on, and rotate the logs and health artifacts for an OpenBSD mail stack.

## Inputs

Primary monitoring inputs are now loaded from `monitoring.conf` in the shared operator input model.

Important values:

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

## Outputs

The phase apply script renders public-safe assets into the repo:

- monitoring nginx location template
- monitoring newsyslog block
- Rspamd logging include
- root cron fragment example
- a monitoring summary of the current operator input model

The broader repo now also contains reusable install, verification, and runtime scripts for:

- log summary generation
- service and listener checks
- static monitoring page rendering
- HTML report generation
- cron-friendly report wrapping
- lightweight maintenance wrappers

## Run

```sh
ksh ./scripts/phases/phase-14-apply.ksh
ksh ./scripts/phases/phase-14-verify.ksh
```

## Then install on a host

```sh
doas ksh ./scripts/install/install-monitoring-assets.ksh --dry-run
doas ksh ./scripts/install/install-monitoring-assets.ksh --apply
```

## Runtime usage

Typical operator commands:

```sh
doas /usr/local/sbin/openbsd-mailstack-monitoring-run
doas /usr/local/sbin/openbsd-mailstack-mail-health-report --stdout > /tmp/mail-health-report.html
doas /usr/local/sbin/openbsd-mailstack-verify-mailstack
```

## Verification

The verify path now checks:

- required monitoring repo assets exist
- rendered phase artifacts exist
- runtime output exists when the operator explicitly requires it

On a real host, also verify:

- `nginx -t`
- `newsyslog -n`
- the rendered monitoring pages under the chosen control-plane path
- that the data directory remains unserved directly


## Higher-fidelity site output

Phase 14 now drives the richer OpenBSD-native static monitor implementation through the same public wrapper scripts. See `docs/install/22-openbsd-native-ops-monitoring-site.md`.
