# Brevo Account, Relay, and API Setup

## Purpose

This document defines the required setup for:

- Brevo account creation
- additional user and admin user access, when needed
- API key creation
- SMTP key creation
- secure handling of credentials
- sender domain authentication for transactional email delivery

This is a prerequisite for:

- Phase 07, filtering and anti-abuse
- any later smart-relay or outbound delivery workflow that uses Brevo

---

## 1. Create a Brevo Account

Create your account using:

`https://onboarding.brevo.com/account/register`

Brevo is used in this project as a smart relay and deliverability support layer when self-hosted outbound mail may be affected by IP reputation or provider blocking.

### Steps

1. Create the account
2. Verify your email address
3. Complete any required onboarding
4. Sign in to the Brevo application

---

## 2. Create Additional Users or Admin Users

User and admin access is managed from:

`https://app.brevo.com/user/member`

Brevo also documents user and permission management in its help center.

Use additional users only when operational separation is needed, for example:

- primary operator account
- secondary admin account
- limited-access team member

Recommended approach for this project:

- keep the number of privileged users low
- use distinct identities for administration
- do not share one credential across multiple operators

---

## 3. Create an API Key

Brevo API overview:

`https://developers.brevo.com/docs/quickstart-reference`

Brevo’s getting started guide uses the `api-key` header for authenticated API access, and its help center documents creating API keys from **Settings → SMTP & API → API Keys & MCP**. citeturn639512view0turn621988search2

### Steps

1. Sign in to Brevo
2. Navigate to **Settings → SMTP & API → API Keys & MCP**
3. Generate a new API key
4. Name it clearly, for example:

```text
openbsd-mailstack-api
```

5. Copy it immediately and store it securely

Brevo’s help center explicitly says to copy the generated key and store it in a safe environment. citeturn621988search2

---

## 4. Create an SMTP Key

Brevo documents SMTP key creation under **Settings → SMTP & API**, where you generate a new SMTP key and may choose the recommended standard secure SMTP key variant. citeturn621988search11

### Steps

1. Sign in to Brevo
2. Navigate to **Settings → SMTP & API**
3. Open the **SMTP** tab
4. Generate a new SMTP key
5. Name it clearly, for example:

```text
openbsd-mailstack-smtp
```

6. Copy it immediately and store it securely

---

## 5. Secure Storage (Mandatory)

The Brevo API key and SMTP key are secrets.

### Requirements

- never commit them to Git
- never place them in tracked repository config files
- never hardcode them into apply or verify scripts
- store them in a secure secret manager or protected local secret file

Recommended options:

- Proton Pass
- Bitwarden
- another secure password store that integrates well with your workstation

---

## 6. Secure Usage Pattern

### Option A, environment variables

```sh
export BREVO_API_KEY="REDACTED"
export BREVO_SMTP_KEY="REDACTED"
```

### Option B, protected local secret file

Example file:

```text
/root/.secrets/brevo.conf
```

Contents:

```sh
BREVO_API_KEY="REDACTED"
BREVO_SMTP_KEY="REDACTED"
```

Permissions:

```sh
chmod 600 /root/.secrets/brevo.conf
```

Then load it only in the local operator environment:

```sh
. /root/.secrets/brevo.conf
```

---

## 7. Authenticate the Sending Domain

Before using Brevo for transactional mail, Brevo says to add and authenticate your domain, and its SMTP guidance lists this as a prerequisite before sending transactional emails. citeturn621988search1turn621988search3

Brevo’s domain authentication workflow is managed under **Settings → Senders, Domains, IPs → Domains**, where you add a domain and authenticate it with records such as the Brevo code, DKIM, and DMARC. citeturn621988search3

### Important project context

For this project:

- your DNS remains authoritative in Vultr
- Brevo gives you the sender-domain authentication records
- you add those records in Vultr DNS
- you verify them in Brevo

This keeps DNS control centralized while still allowing Brevo to authenticate outbound mail for relay use.

---

## 8. Why Brevo Exists in This Project

This project is primarily a self-hosted mail system, but self-hosted outbound mail can still encounter:

- IP reputation issues
- port 25 restrictions
- provider-level delivery friction

Brevo is included to support outbound resilience when direct delivery is not acceptable or fails operationally.

This means:

- the OpenBSD Mailstack remains the primary platform
- Brevo is the controlled smart-relay and deliverability support layer
- relay use should be explicit and documented, not hidden

Brevo also notes that the SMTP login should be used for configuration purposes and not as the sender address, and that if the sender domain is authenticated, you do not need to verify individual senders. citeturn621988search5

---

## 9. Where this is used

Primary usage in this project:

- Phase 07, filtering and anti-abuse

Supporting usage:

- outbound smart-relay configuration
- sender domain authentication
- deliverability recovery paths for self-hosted environments

Expected usage pattern:

- the public repo documents the relay model
- the operator stores credentials securely outside Git
- any live relay configuration consumes local secret values only

---

## 10. Security Notes

- treat the API key and SMTP key as privileged credentials
- keep the number of privileged Brevo users low
- rotate keys periodically
- revoke keys immediately if exposed
- review sender-domain authentication before production use

---

## Verification Checklist

- [ ] Brevo account created
- [ ] any required additional admin users created
- [ ] API key generated
- [ ] SMTP key generated
- [ ] sender domain added in Brevo
- [ ] sender domain authentication records created in Vultr DNS
- [ ] keys stored securely outside the repository
- [ ] no Brevo keys present in tracked files
