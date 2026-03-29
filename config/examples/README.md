# Configuration Examples

This directory holds repo-safe examples for operator-provided input files.

Use these files together with:

- `config/system.conf.example`
- `config/network.conf.example`
- `config/domains.conf.example`
- `config/secrets.conf.example`
- `config/backup.conf.example`
- `config/backup-schedule.conf.example`
- `config/dr-site.conf.example`
- `config/dr-host.conf.example`
- `config/monitoring.conf.example`
- `config/maintenance.conf.example`

Recommended approach:

1. keep tracked examples unchanged
2. create real local values in ignored paths such as `config/system.conf`, `config/backup.conf`, `config/local/backup-schedule.conf`, or `config/local/dr-host.conf`
3. store provider credentials, encryption recipients, and off-host targets in ignored files, not in tracked examples

Provider examples in this directory match the supported loader search paths documented in:

- `docs/install/provider-account-and-credential-onboarding.md`
- `docs/install/user-input-file-layout.md`
- `docs/install/13-dr-site-provisioning.md`
- `docs/install/15-dr-host-bootstrap.md`
- `docs/install/16-monitoring-diagnostics-and-reporting.md`
- `docs/install/17-maintenance-upgrades-regression-and-rollback.md`

## Maintenance and upgrade inputs

Later public phases also support a tracked example for maintenance and upgrade policy inputs.
Use `config/maintenance.conf.example` as the starting point, then place real operator values in one of the ignored local input paths described in `docs/install/user-input-file-layout.md`.
