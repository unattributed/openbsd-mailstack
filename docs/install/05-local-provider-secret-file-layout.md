# Local Provider Secret File Layout

## Purpose

This document defines the preferred local file layout for external provider secrets in the public `openbsd-mailstack` baseline.

The goal is simple:

- keep secrets out of Git
- keep provider credentials predictable for operators
- keep file ownership and permissions easy to audit

## Preferred layout

```text
/root/.config/vultr/api.env
/root/.config/brevo/brevo.env
/root/.config/virustotal/vt.env
```

## Required properties

- owner: `root`
- mode: `0600`

Example:

```sh
chmod 600 /root/.config/vultr/api.env
chmod 600 /root/.config/brevo/brevo.env
chmod 600 /root/.config/virustotal/vt.env
```

## Example contents

### Vultr

```sh
VULTR_API_KEY="REDACTED"
VULTR_API_URL="https://api.vultr.com/v2"
MAIL_NOTIFY="ops@example.com"
MAIL_FROM="ops@example.com"
GITHUB_PAGES_DOMAINS="example.com example.org"
ALLOWED_IPV4_CIDRS=""
DEFAULT_TTL="300"
VULTR_DOMAINS="example.com example.net example.org"
VULTR_HOSTS_example.com="@ mail obsd1 www"
VULTR_HOSTS_example.net="@ mail obsd1 www"
VULTR_HOSTS_example.org="mail obsd1"
VULTR_TTL_DEFAULT=300
```

### Brevo

```sh
BREVO_SMTP_LOGIN="REDACTED provided by brevo"
BREVO_SMTP_PASSWORD="REDACTED"
BREVO_SMTP_HOST="smtp-relay.brevo.com"
BREVO_SMTP_PORT=587
BREVO_API_KEY="REDACTED"
```

### VirusTotal

```sh
VT_API_KEY="REDACTED"
VT_SCAN_ENABLED=1
VT_MINIMUM_ENGINES=3
VT_LOW_CATEGORY=5
VT_MEDIUM_CATEGORY=10
VT_SCORE_CLEAN=-0.5
VT_SCORE_LOW=2.0
VT_SCORE_MEDIUM=5.0
VT_SCORE_HIGH=8.0
VT_MAX_SIZE_BYTES=20000000
VT_PUBLIC_MAX_REQUESTS_PER_MINUTE=4
VT_PUBLIC_MAX_REQUESTS_PER_DAY=500
VT_PUBLIC_MAX_REQUESTS_PER_MONTH=15500
```

## Security rule

These files are local operational artifacts. They are not repository content and must never be committed to Git.
