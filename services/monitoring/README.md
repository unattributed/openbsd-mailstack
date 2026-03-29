# Monitoring, Diagnostics, Logging, and Reporting Assets

This directory holds public-safe monitoring and reporting templates for the operational visibility layer.

Contents:

- `cron/root.cron.fragment.template`, a repo-safe cron snippet for periodic monitoring collection and daily HTML reporting
- nginx location templates under `services/nginx/`
- log rotation overlays under `services/system/`
- rendered examples under `services/generated/rootfs/`

Use `scripts/phases/phase-14-apply.ksh` to render example assets into `services/generated/rootfs/`, then use `scripts/install/install-monitoring-assets.ksh` when you are ready to install them onto an OpenBSD host.
