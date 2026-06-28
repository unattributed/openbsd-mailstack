# Sanitized reconciliation evidence

Timestamp: `2026-06-28T03:09:37Z`

Scope: repository `c285d98`, deployed OSMAP, and read-only inspection of `mail.blackbagsecurity.com`.

## Source controls

- OpenBSD release status was verified from `https://www.openbsd.org/` and `https://www.openbsd.org/79.html`.
- Maintenance behavior was checked against the OpenBSD 7.9 manuals and 7.8 to 7.9 upgrade guide.
- Product checks were selected from official Postfix, Dovecot, Rspamd, and nginx documentation.
- No secret values, private peer addresses, current WAN address, message data, credentials, or private keys were captured.

## Observed host

```text
OpenBSD 7.9 amd64
installed syspatches: 001_xserver 002_smtpd 003_vmd
pending syspatches: none
```

Selected package versions:

```text
postfix-3.11.4v0-sasl2-mysql
dovecot-2.3.21.1p3v0
rspamd-4.1.1v0
nginx-1.30.3
mariadb-server-11.4.12v1
redis-6.2.22p1
roundcubemail-1.6.16
sogo-5.12.9
```

Enabled service checks passed for Postfix, Dovecot, Rspamd, nginx, MariaDB, Redis, SOGo, PHP 8.3 FPM, ClamAV, FreshClam, Unbound, Vultr DDNS, `osmap_serve`, and `osmap_mailbox_helper`. NSD and unwind were absent.

Syntax and load checks passed:

```text
postfix check
doveconf -n
rspamadm configtest
nginx -t
pfctl -nf /etc/pf.conf
unbound-checkconf /var/unbound/etc/unbound.conf
acme-client -n mail.blackbagsecurity.com
```

The expected SMTP, HTTP, HTTPS, submission, IMAPS, private Rspamd control, and loopback OSMAP listeners were present. Addresses were reduced to scope categories before review.

## DDNS

`vultr_ddns` was enabled and healthy. Artifacts:

```text
/usr/local/sbin/vultr_ddns_multi.py  root:wheel 0555
sha256 57533f54a0759748d2ade6587b4e121e4f0f9949f555159a45e59000085ef395

/usr/local/sbin/vultr_ddns_service.sh  root:wheel 0555
sha256 23a9683bca6f31c78a527c9a7600e85d87e5eb3c3978a2134ba957803db1b535

/etc/rc.d/vultr_ddns  root:wheel 0555
sha256 741e526c8501c917fb84b25b9adf28a4df937f29e1579e3f469e1de9e90ab354
```

No static WAN address is asserted.

## OSMAP

The deployed checkout was clean on `main` at `a096751ce55863ab3edd8ad9da29e7631c4949f1`.

```text
/usr/local/bin/osmap
sha256 333a417bf435ae74bfc2b7a9eebedeca1ad541cb527e2555fed408e11e24d963

osmap-serve.env             root:osmaprt 0640
osmap-mailbox-helper.env    root:vmail   0640
mailbox-helper.sock         vmail:osmaprt 0660
auth socket                 _osmap:_osmap 0660
userdb socket               vmail:vmail   0660
```

nginx routed OSMAP only to loopback port 8080. Browser-facing GET checks returned:

```text
/healthz 200
/        303
/login   200
invalid Host 421
```

The final production regression runner was streamed to the host in read-only mode. All 59 checks passed, including IMAPS, SMTPS, and submission STARTTLS handshakes. Its timestamped host-local report and checksum remain operator evidence and are not copied into this public summary.

## TLS

The certificate was present and valid from 2026-05-22 through 2026-08-20. The full chain was `0444`; the private key was `root:wheel 0600`. No key content or key checksum was captured.

## Unresolved by this read-only run

- No message was queued, so end-to-end SMTP, filtering, LMTP, and mailbox arrival need an operator-authorized `--apply --probe-to` run.
- No restore was performed. Backup completeness and recovery time remain separate drill evidence.
- Vultr API state and the current WAN address were intentionally not captured.
- The live `pkg_add -u -n -I` preview was interrupted during a slow package fetch. `pkg_check -n -I` passed, and the wrapper's bounded timeout exited cleanly with no orphaned package process. Re-run the full preview in the maintenance window.
