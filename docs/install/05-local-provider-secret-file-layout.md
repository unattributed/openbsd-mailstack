# Local Provider Secret File Layout

## Purpose

This document defines the preferred local file layout for provider credentials in the public `openbsd-mailstack` baseline.

Use it together with:

- `provider-account-and-credential-onboarding.md`
- `user-input-file-layout.md`

## Recommended locations

Preferred repo-local ignored paths:

```text
config/local/providers/vultr.env
config/local/providers/brevo.env
config/local/providers/virustotal.env
```

Preferred protected host-local paths:

```text
/root/.config/openbsd-mailstack/providers/vultr.env
/root/.config/openbsd-mailstack/providers/brevo.env
/root/.config/openbsd-mailstack/providers/virustotal.env
```

Supported legacy paths:

```text
/root/.config/vultr/api.env
/root/.config/brevo/brevo.env
/root/.config/virustotal/vt.env
```

## Required properties

For any file containing live secrets:

- owner: `root`
- mode: `0600`

Example:

```sh
chmod 600 /root/.config/openbsd-mailstack/providers/vultr.env
chmod 600 /root/.config/openbsd-mailstack/providers/brevo.env
chmod 600 /root/.config/openbsd-mailstack/providers/virustotal.env
```

## Example contents

### Vultr

```sh
VULTR_API_KEY="REDACTED"
VULTR_API_URL="https://api.vultr.com/v2"
MAIL_NOTIFY="ops@example.com"
MAIL_FROM="ops@example.com"
DEFAULT_TTL="300"
VULTR_DOMAINS="example.com example.net"
VULTR_HOSTS_example.com="@ mail"
VULTR_HOSTS_example.net="@ mail"
```

### Brevo

```sh
BREVO_SMTP_LOGIN="REDACTED"
BREVO_SMTP_PASSWORD="REDACTED"
BREVO_SMTP_HOST="smtp-relay.brevo.com"
BREVO_SMTP_PORT="587"
BREVO_API_KEY="REDACTED"
```

### VirusTotal

```sh
VT_API_KEY="REDACTED"
VT_SCAN_ENABLED="1"
VT_MINIMUM_ENGINES="3"
VT_LOW_CATEGORY="5"
VT_MEDIUM_CATEGORY="10"
VT_SCORE_CLEAN="-0.5"
VT_SCORE_LOW="2.0"
VT_SCORE_MEDIUM="5.0"
VT_SCORE_HIGH="8.0"
VT_MAX_SIZE_BYTES="20000000"
```

## Shared loader behavior

The public loader in `scripts/lib/operator-inputs.ksh` reads these files automatically when they exist and are readable. That keeps provider credentials out of tracked files while still letting later phase scripts consume them consistently.

## Security rule

These files are local operational artifacts. They are not repository content and must never be committed to Git.
