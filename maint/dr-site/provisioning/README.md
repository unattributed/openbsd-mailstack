# DR Host Provisioning Notes

This directory describes the public-safe bootstrap layout for a standby DR host.

The preferred entry point is:

- `scripts/install/provision-dr-site-host.ksh`

That script creates the base DR host filesystem layout, prepares restore and backup
roots, and can call `scripts/install/install-dr-site-assets.ksh` to publish the
DR portal.

Provisioning is non-destructive by default when used with `--dry-run`.
