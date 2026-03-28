# Brevo Account, Relay, and API Setup

## Purpose

This document defines the required setup for:

- Brevo account creation
- additional user and admin user access, when needed
- API key creation
- SMTP key creation
- secure handling of credentials
- sender domain authentication for transactional email delivery

This is a prerequisite for outbound smart-relay or deliverability support workflows in the public baseline.

## 1. Create a Brevo Account

Create your account using:

`https://onboarding.brevo.com/account/register`

Brevo is used in this project as a smart-relay and deliverability support layer when self-hosted outbound mail may be affected by IP reputation or provider blocking.

### Steps

1. Create the account
2. Verify your email address
3. Complete any required onboarding
4. Sign in to the Brevo application

## 2. Create Additional Users or Admin Users

User and admin access is managed from:

`https://app.brevo.com/user/member`

Use additional users only when operational separation is needed, for example:

- primary operator account
- secondary admin account
- limited-access team member

Recommended approach for this project:

- keep the number of privileged users low
- use distinct identities for administration
- do not share one credential across multiple operators

## 3. Create an API Key

API overview:

`https://developers.brevo.com/docs/quickstart-reference`

Steps:

1. Sign in to Brevo
2. Navigate to **Settings → SMTP & API → API Keys & MCP**
3. Generate a new API key
4. Name it clearly
5. Copy it immediately and store it securely

## 4. Create an SMTP Key

Steps:

1. Sign in to Brevo
2. Navigate to **Settings → SMTP & API**
3. Open the **SMTP** tab
4. Generate a new SMTP key
5. Copy it immediately and store it securely

## 5. Secure Storage

The Brevo API key and SMTP key are secrets.

### Requirements

- never commit them to Git
- never place them in tracked repository config files
- never hardcode them into apply or verify scripts
- store them in a secure secret manager or protected local secret file

### Preferred local file pattern

```text
/root/.config/brevo/brevo.env
```

Example contents:

```sh
BREVO_SMTP_LOGIN="REDACTED provided by brevo"
BREVO_SMTP_PASSWORD="REDACTED"
BREVO_SMTP_HOST="smtp-relay.brevo.com"
BREVO_SMTP_PORT=587
BREVO_API_KEY="REDACTED"
```

Permissions:

```sh
chmod 600 /root/.config/brevo/brevo.env
```

## 6. Authenticate the Sending Domain

Before using Brevo for transactional mail, add and authenticate your sender domain in Brevo.

For this project:

- your DNS remains authoritative in Vultr
- Brevo provides sender-domain authentication records
- you add those records in Vultr DNS
- you verify them in Brevo

## 7. Why Brevo Exists in This Project

This project is primarily a self-hosted mail system, but self-hosted outbound mail can still encounter:

- IP reputation issues
- port 25 restrictions
- provider-level delivery friction

Brevo is included to support outbound resilience when direct delivery fails or is operationally unsuitable.

## 8. Where this is used

Primary usage in this project:

- outbound smart-relay configuration
- sender-domain authentication
- deliverability recovery paths for self-hosted environments

All live Brevo usage should reference secure runtime values or protected local files only.

## 9. Verification Checklist

- [ ] Brevo account created
- [ ] any required additional admin users created
- [ ] API key generated
- [ ] SMTP key generated
- [ ] sender domain added in Brevo
- [ ] sender-domain authentication records created in Vultr DNS
- [ ] keys stored securely outside the repository
- [ ] no Brevo keys present in tracked files
