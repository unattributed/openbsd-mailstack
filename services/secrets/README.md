# Runtime Secrets and Key Material Assets

This directory holds public-safe assets for Phase 16.

Included here:

- host-local runtime secret file templates
- PHP secret file templates for PostfixAdmin and Roundcube
- env-style templates for database and provider credentials
- layout and permissions guidance for host-local secret files

Not included here:

- real passwords, API keys, or PATs
- real TLS, DKIM, or WireGuard private keys
- live restore archives or encrypted evidence

Use the tracked templates together with:

- `config/secrets-runtime.conf.example`
- `maint/runtime-secret-layout.ksh`
- `maint/repo-secret-guard.ksh`
