# OpenBSD native ops monitor parity

This directory documents the higher-fidelity static monitoring site ported from the private `openbsd-self-hosting` repository into `openbsd-mailstack` in a public-safe way.

The runtime implementation now lives in:

- `scripts/ops/monitoring-collect.ksh`
- `scripts/ops/monitoring-render.ksh`
- `scripts/ops/monitoring-run.ksh`
- `scripts/verify/verify-monitoring-assets.ksh`

These scripts produce a richer `/_ops/monitor/` site with overview, host, network, PF, mail, Rspamd, Dovecot, Postfix, web, DNS, IDS, VPN, storage, backups, agent, and change pages when the required runtime data is available.

The design remains public-safe:

- live hostnames are replaced with operator-provided values
- control-plane paths remain ACL-gated
- raw data paths remain denied through nginx
- optional later-phase governance and private-only evidence remain outside the public repo
