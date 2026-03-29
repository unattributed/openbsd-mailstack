# Configuration Examples

This directory holds repo-safe examples for operator-provided input files.

Use these tracked examples as the truth layer for the public repository:

- `config/system.conf.example`
- `config/network.conf.example`
- `config/domains.conf.example`
- `config/secrets.conf.example`
- `config/dns.conf.example`
- `config/ddns.conf.example`
- `config/backup.conf.example`
- `config/backup-schedule.conf.example`
- `config/dr-site.conf.example`
- `config/dr-host.conf.example`
- `config/monitoring.conf.example`
- `config/maintenance.conf.example`
- `config/security.conf.example`
- `config/secrets-runtime.conf.example`

Recommended approach:

1. keep tracked examples unchanged
2. create real local values in ignored paths such as `config/local/`
3. store provider credentials in ignored provider files, not in tracked examples
4. render staged assets before applying them to a host
5. keep runtime secrets and private keys in host-local files, not in Git

Provider examples in this directory match the supported loader search paths documented in:

- [Provider account and credential onboarding](../../docs/install/provider-account-and-credential-onboarding.md)
- [User input file layout](../../docs/install/user-input-file-layout.md)
- [Vultr account and API setup](../../docs/install/02-vultr-account-and-api-setup.md)
- [Security hardening and runtime secrets](../../docs/install/21-security-hardening-and-runtime-secrets.md)
