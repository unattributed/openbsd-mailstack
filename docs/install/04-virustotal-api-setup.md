# VirusTotal API Setup

## Purpose

This document defines the required setup for:

- VirusTotal account creation
- API key creation
- secure handling of the API key
- quota-aware and privacy-aware use in the public mailstack baseline

VirusTotal should be treated as an optional external reputation and attachment analysis layer, not as an always-on requirement for every message.

## 1. Create a VirusTotal Account

Create your account at:

`https://www.virustotal.com/`

Then locate your API key from the account area, typically exposed in the VirusTotal web interface.

## 2. Generate or Retrieve the API Key

Use the key shown in your VirusTotal account.

The public baseline assumes:

- you copy the key once
- you store it securely
- you do not place it in the repository

## 3. Secure Storage

The VirusTotal API key is a secret.

### Requirements

- never commit it to Git
- never place it in tracked repository config files
- never hardcode it into apply or verify scripts
- store it in a secure password manager or protected local secret file

### Preferred local file pattern

```text
/root/.config/virustotal/vt.env
```

Example contents:

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

Permissions:

```sh
chmod 600 /root/.config/virustotal/vt.env
```

## 4. Usage Limits and Privacy Warning

VirusTotal public API usage is limited and should be treated carefully.

Operational guidance:

- do not assume every attachment should be sent to a third party
- respect the public API quotas
- understand the privacy implications before enabling external file analysis
- prefer selective use for suspicious content rather than blind universal forwarding

## 5. Where this is used

Primary usage in this project:

- optional external attachment or reputation analysis
- security review workflows
- malware or suspicious artifact escalation

All live VirusTotal usage should reference secure runtime values or protected local files only.

## 6. Verification Checklist

- [ ] VirusTotal account created
- [ ] API key retrieved
- [ ] API key stored securely outside the repository
- [ ] no VirusTotal key present in tracked files
- [ ] quota and privacy implications reviewed
