# Advanced operations and optional integrations

## Purpose

This runbook defines a practical operator review pattern for the late optional integrations added in the public repo.

## Suricata review

- confirm `/etc/suricata/suricata.yaml` matches the rendered baseline you intended to deploy
- confirm `eve.json` is rotating and readable
- run `suricata-dump.ksh` to refresh dashboard summaries
- keep `suricata-eve2pf.ksh` in watch mode until you have confidence in the alert profile

## Brevo webhook review

- confirm the listener remains bound to loopback
- confirm nginx alone exposes the webhook path
- review `/var/log/brevo-webhook.log`
- confirm the state file updates when test events are posted

## SOGo review

- confirm SOGo remains behind the same access-control model as the rest of the web plane
- confirm `sogo.conf` ownership and modes
- test `.well-known/caldav` and `.well-known/carddav` redirects only after the rest of the mail stack is stable

## SBOM review

- run `sbom-daily-scan.ksh --scanner fallback` if you only need inventory freshness
- use `--scanner mapped` when you have the dependencies and want NVD coverage for mapped components
- review exception expiry dates before they become operational debt
- keep reports out of Git and under generated output paths only
