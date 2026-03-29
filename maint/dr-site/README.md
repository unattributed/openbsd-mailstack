# DR Site Assets

This directory holds the public-safe disaster recovery site assets for `openbsd-mailstack`.

Purpose:

- provide an internal DR portal under `/dr/`
- expose a concise runbook and operator sequence without embedding secrets
- keep deployment repo-managed and repeatable

Contents:

- `htdocs/` static pages rendered by `scripts/install/install-dr-site-assets.ksh`
- `nginx/dr-site.locations.template` location block template for nginx
- `assets/` shared CSS and JavaScript used by the rendered pages

These files are intentionally generic. Operator-specific values such as hostnames, allowlist templates, and contact email addresses come from `config/dr-site.conf` or another supported ignored input path.
