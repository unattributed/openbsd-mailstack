# Suricata

This directory holds a public-safe Suricata IDS baseline for OpenBSD mail hosts.

Included here:

- `suricata.yaml.template`
- `threshold.config.template`
- `local.rules.template`
- helper scripts for dashboard export and PF watch or block candidate generation

The templates are intentionally sanitized. Real interfaces, public IPs, and policy choices come from operator input files.
