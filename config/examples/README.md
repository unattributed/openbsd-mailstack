# Configuration Examples

This directory holds repo-safe examples for operator-provided input files.

Use these tracked examples as the truth layer for the public repo:

- `config/system.conf.example`
- `config/network.conf.example`
- `config/domains.conf.example`
- `config/secrets.conf.example`
- `config/dns.conf.example`
- `config/ddns.conf.example`

Recommended approach:

1. keep tracked examples unchanged
2. create real local values in ignored paths such as `config/local/`
3. store provider credentials in ignored provider files, not in tracked examples
4. render staged assets before applying them to a host

Provider examples in this directory match the supported loader search paths documented in:

- `docs/install/provider-account-and-credential-onboarding.md`
- `docs/install/user-input-file-layout.md`
- `docs/install/02-vultr-account-and-api-setup.md`
