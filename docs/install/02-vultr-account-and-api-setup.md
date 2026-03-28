# Vultr Account, DNS, and API Setup

## Purpose

This document defines the required setup for:

- domain DNS hosting
- API access
- secure handling of credentials

This is a prerequisite for:

- Phase 00, foundation
- Phase 09, DNS and identity publishing

---

## 1. Create a Vultr Account

Sign up using:

`https://www.vultr.com/?ref=7976926`

Vultr is used as the authoritative DNS provider for this project.

### Steps

1. Create an account
2. Verify your email address
3. Complete billing setup if required

---

## 2. Configure Domain DNS

1. Navigate to: **Products → DNS**
2. Add your domain
3. Note the nameservers provided by Vultr, typically similar to:

```text
ns1.vultr.com
ns2.vultr.com
```

4. Update your domain registrar to use the Vultr nameservers

### Verify

```sh
dig NS example.com
```

---

## 3. Generate API Key

API overview:

`https://www.vultr.com/api/`

Steps:

1. Account → API
2. Enable API access
3. Generate an API key

---

## 4. Secure Storage (Mandatory)

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

---

## 5. Secure Usage Pattern

### Option A, environment variable

```sh
export VULTR_API_KEY="REDACTED"
```

### Option B, protected local secret file

Example file:

```text
/root/.secrets/vultr.conf
```

Contents:

```sh
VULTR_API_KEY="REDACTED"
```

Permissions:

```sh
chmod 600 /root/.secrets/vultr.conf
```

Then load it only in the local operator environment:

```sh
. /root/.secrets/vultr.conf
```

---

## 6. Where this is used

Primary usage in this project:

- Phase 09, DNS and identity publishing

Expected usage pattern:

- the public repo generates DNS record guidance
- the operator applies those records in Vultr DNS
- any later API-driven automation must load `VULTR_API_KEY` securely at runtime
- no tracked config file in this repository should contain the live key

Potential future usage:

- DNS automation
- record validation scripts
- dynamic DNS update tooling

---

## 7. Security Notes

- treat the API key as equivalent to privileged DNS control
- rotate it periodically
- revoke it immediately if exposed
- review where it is stored before each major DNS change

---

## Verification Checklist

- [ ] Vultr account created
- [ ] domain added to Vultr DNS
- [ ] nameservers updated at registrar
- [ ] API key generated
- [ ] API key securely stored
- [ ] API key not present in repository
- [ ] chosen storage approach works on the operator workstation
