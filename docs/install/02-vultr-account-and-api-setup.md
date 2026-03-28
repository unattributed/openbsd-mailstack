# Vultr Account, DNS, and API Setup

## Purpose

This document defines the required setup for:

- domain DNS hosting
- API access
- secure handling of credentials

This is a prerequisite for DNS-related workflows in the public baseline.

## 1. Create a Vultr Account

Sign up using:

`https://www.vultr.com/?ref=7976926`

Vultr is used as the authoritative DNS provider for this project.

### Steps

1. Create an account
2. Verify your email address
3. Complete billing setup if required

## 2. Configure Domain DNS

1. Navigate to **Products → DNS**
2. Add your domain
3. Note the Vultr nameservers provided
4. Update your registrar to use the Vultr nameservers

### Verify

```sh
dig NS example.com
```

## 3. Generate API Key

API overview:

`https://www.vultr.com/api/`

Steps:

1. Go to **Account → API**
2. Enable API access
3. Generate an API key

## 4. Secure Storage

The API key is a secret.

### Requirements

- never commit it to Git
- never place it in tracked repository config files
- never hardcode it into apply or verify scripts
- store it in a secure secret manager or protected local secret file

Recommended options:

- Proton Pass
- Bitwarden
- another secure password store that integrates well with your workstation

## 5. Secure Usage Pattern

### Option A, environment variable

```sh
export VULTR_API_KEY="REDACTED"
```

### Option B, protected local secret file

Example file:

```text
/root/.config/vultr/api.env
```

Contents:

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

Permissions:

```sh
chmod 600 /root/.config/vultr/api.env
```

## 6. Where this is used

Primary usage in this project:

- DNS and identity publishing
- optional dynamic DNS or validation tooling

All live API usage should reference secure runtime values or protected local files, not tracked repository content.

## 7. Security Notes

- treat the API key as privileged DNS control
- rotate it periodically
- revoke it immediately if exposed
- review where it is stored before each major DNS change

## Verification Checklist

- [ ] Vultr account created
- [ ] domain added to Vultr DNS
- [ ] nameservers updated at registrar
- [ ] API key generated
- [ ] API key securely stored
- [ ] API key not present in repository
