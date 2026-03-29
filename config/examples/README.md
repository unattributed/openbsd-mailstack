# Configuration Examples

This directory holds repo-safe examples for operator-provided input files.

Use these files together with:

- `config/system.conf.example`
- `config/network.conf.example`
- `config/domains.conf.example`
- `config/secrets.conf.example`
- `config/backup.conf.example`
- `config/dr-site.conf.example`

Recommended approach:

1. keep tracked examples unchanged
2. create real local values in ignored paths such as `config/system.conf`, `config/backup.conf`, or `config/local/`
3. store provider credentials and off-host targets in ignored files, not in tracked examples

Provider examples in this directory match the supported loader search paths documented in:

- `docs/install/provider-account-and-credential-onboarding.md`
- `docs/install/user-input-file-layout.md`
- `docs/install/13-dr-site-provisioning.md`
