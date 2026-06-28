# mail.blackbagsecurity.com production and OSMAP integration

## Evidence boundary

This document separates reusable design from observed production state. Observations were collected read-only on 2026-06-28T03:09:37Z. The sanitized record is in `evidence/20260628T030937Z/README.md`. Values that can grant access, identify private peers, or reveal the current WAN address are excluded.

## Intended architecture

The supported design remains a small OpenBSD mail host:

- Postfix owns SMTP and local `sendmail` compatibility.
- Dovecot owns IMAP, LMTP, Sieve, authentication, and mailbox access.
- Rspamd, Redis, ClamAV, and FreshClam provide filtering support.
- MariaDB supports virtual mail data and existing web administration.
- nginx terminates HTTPS and keeps public and private routes separate.
- PF controls exposure. Unbound is the local validating resolver.
- `acme-client` manages the shared mail and HTTPS certificate.
- Vultr DNS is updated by a host-local DDNS service. No static WAN address is assumed.
- OSMAP is the public browser mail interface. It remains server rendered and JavaScript free.

OpenSMTPD, NSD, and unwind are not part of the observed production service set. They remain valid OpenBSD software, but documentation must not claim they serve this host.

## Observed production configuration

The host reported OpenBSD 7.9 amd64. Installed errata patches were `001_xserver`, `002_smtpd`, and `003_vmd`; `syspatch -c` reported no pending patch. The following services were enabled and healthy:

```text
postfix dovecot rspamd nginx mysqld redis sogod php83_fpm
clamd freshclam unbound vultr_ddns osmap_serve osmap_mailbox_helper
```

Postfix, Dovecot, Rspamd, nginx, PF, Unbound, and ACME configuration checks passed. The observed TCP surface included SMTP 25, HTTP 80, HTTPS 443, submissions 465 and 587, IMAPS 993, and the private Rspamd control listener 11334. OSMAP port 8080 was loopback-only.

Roundcube, SOGo, and PostfixAdmin packages remain installed for private or compatibility workflows. Their presence does not make them the public browser mail interface.

## Dynamic DNS

The WAN address is dynamic. The enabled `vultr_ddns` rc.d service launches the local wrapper around:

```text
/usr/local/sbin/vultr_ddns_multi.py
/usr/local/sbin/vultr_ddns_service.sh
/etc/rc.d/vultr_ddns
```

The API credential and live address are host-local and must never enter Git or evidence output. Regression checks validate program presence, ownership, mode, and service health only.

## OSMAP integration

The deployed OSMAP repository was clean on `main` at commit `a096751ce55863ab3edd8ad9da29e7631c4949f1`. The deployed binary SHA256 was recorded in the evidence summary.

The active request and mail paths are:

```text
browser HTTPS
  -> nginx public vhost
  -> 127.0.0.1:8080 osmap_serve
  -> /var/run/osmap-auth for Dovecot authentication
  -> /var/lib/osmap-helper/run/mailbox-helper.sock
  -> osmap_mailbox_helper as vmail
  -> /var/run/osmap-userdb and Dovecot mailbox operations

OSMAP compose
  -> /usr/sbin/sendmail mailwrapper
  -> /usr/local/sbin/sendmail
  -> Postfix
```

The browser process runs separately from the mailbox helper. The service environment files are `root:osmaprt 0640` and `root:vmail 0640`; the helper socket is `vmail:osmaprt 0660`. nginx includes distinct public and private OSMAP route templates and sends OSMAP traffic only to loopback.

Observed browser-facing GET results were:

```text
GET /healthz  200
GET /         303
GET /login    200
invalid Host  421
```

Use GET for these checks. OSMAP does not treat HEAD as a browser-equivalent acceptance probe.

## Known assumptions removed

- OpenBSD 7.8 is no longer the active baseline.
- The WAN address is not static.
- OpenSMTPD does not own production SMTP. Postfix does.
- NSD and unwind are not enabled production services. Unbound is.
- Roundcube is not the public browser mail frontend. OSMAP is.
- OSMAP does not access mailboxes directly from its public process.
- Public OSMAP availability does not imply that private administration routes are public.

## Disaster recovery notes

Back up and restore these as separate control units:

1. base and package inventory, `/etc`, PF, rc configuration, and certificate automation;
2. Postfix, Dovecot, Rspamd, MariaDB, Redis, and mailbox state;
3. DDNS program and wrapper, but never export its credential into public evidence;
4. OSMAP binary, rc scripts, launchers, environment files, state, TOTP material, and mailbox-helper grant key;
5. nginx public and private route templates and logs.

After a staged restore, run configuration checks before starting services, then `maint/production-regression.ksh --host`. Queue an end-to-end probe only with the explicit `--apply --probe-to` form.

## Operator rule

Treat this document as a dated observation, not a hidden source of truth. Re-run the regression suite and create new sanitized evidence whenever packages, service topology, DDNS wiring, OSMAP, TLS, or edge configuration changes.
