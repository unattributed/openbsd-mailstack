# OpenBSD 7.9 SDLC maintenance runbook

## Authority

OpenBSD 7.9 is the current release, released 2026-05-19:

- [OpenBSD 7.9 release](https://www.openbsd.org/79.html)
- [OpenBSD 7.9 errata](https://www.openbsd.org/errata79.html)
- [OpenBSD 7.8 to 7.9 upgrade guide](https://www.openbsd.org/faq/upgrade79.html)
- [syspatch(8)](https://man.openbsd.org/OpenBSD-7.9/syspatch.8)
- [pkg_add(1)](https://man.openbsd.org/OpenBSD-7.9/pkg_add.1)
- [pkg_check(8)](https://man.openbsd.org/OpenBSD-7.9/pkg_check.8)
- [rcctl(8)](https://man.openbsd.org/OpenBSD-7.9/rcctl.8)
- [sysupgrade(8)](https://man.openbsd.org/OpenBSD-7.9/sysupgrade.8)

`syspatch` maintains base-system errata. `pkg_add -u` updates packages. `pkg_check -n -I` validates installed package consistency without repair. They are separate operations.

## Change preparation

1. Confirm console or alternate root access.
2. Confirm a recent verified backup and rollback artifacts.
3. Confirm `/usr` and `/var` free space.
4. Review the 7.9 errata and package change notices.
5. Rehearse in the 7.9 QEMU path when service or package changes are material.
6. Record the repo commit, host snapshot, config checksums, package list, and installed patches.

Do not alter `/etc/installurl` as a fallback during a maintenance run. Diagnose mirror or network failure and retry only after the cause is understood.

## Read-only report

From a clean host checkout:

```sh
cd /path/to/openbsd-mailstack
doas ksh scripts/ops/maintenance-run.ksh --report
```

This runs preflight checks, records a timestamped snapshot and checksums, previews `syspatch` and package updates, runs `pkg_check -n -I`, validates services and configs, and performs read-only OSMAP checks.

Individual checks are:

```sh
doas ksh maint/openbsd-syspatch.ksh --check
doas ksh maint/openbsd-pkg-upgrade.ksh --check
doas ksh maint/production-regression.ksh --host
```

## Apply OpenBSD 7.9 errata and package updates

Use a defined change window:

```sh
cd /path/to/openbsd-mailstack
doas ksh scripts/ops/maintenance-run.ksh --apply
```

The apply path runs, in order:

```sh
syspatch
pkg_add -u -I
pkg_check -n -I
ksh maint/production-regression.ksh --host
```

Review package readmes and logs before restarting a service. Use `rcctl configtest service` where the rc script supports it. The explicit syntax checks used here are:

```sh
postfix check
doveconf -n >/dev/null
rspamadm configtest
nginx -t
pfctl -nf /etc/pf.conf
unbound-checkconf /var/unbound/etc/unbound.conf
acme-client -n mail.blackbagsecurity.com
```

These choices follow the OpenBSD manuals and the upstream [Postfix](https://www.postfix.org/BASIC_CONFIGURATION_README.html), [Dovecot](https://doc.dovecot.org/main/core/man/doveconf.1.html), [Rspamd](https://docs.rspamd.com/administration/rspamadm/configuration/), and [nginx](https://nginx.org/en/docs/switches.html) documentation.

## Mail-flow probe

The default regression run never queues mail. Queue a controlled probe only with explicit authorization:

```sh
doas ksh maint/production-regression.ksh \
  --host --apply --probe-to operator@example.net
```

Verify Postfix acceptance, Rspamd processing, Dovecot LMTP delivery, and mailbox visibility from logs and the recipient mailbox. Do not put a real address in tracked config.

## Release upgrades

`sysupgrade` is not part of routine 7.9 errata maintenance. For a future release:

1. wait for the official next-release guide;
2. upgrade only from one release to the immediately following release;
3. test an equivalent local system first;
4. review configuration and package changes;
5. run `sysupgrade`, complete `sysmerge`, remove obsolete files as directed, run `pkg_add -u`, update firmware, reboot, and run the regression suite.

Never infer a future command sequence from this 7.9 runbook alone.

## Rollback and failure handling

- Stop on the first failed patch, package, consistency, syntax, service, TLS, or OSMAP check.
- Preserve `/var/syspatch` rollback data. `syspatch -r` reverts the most recent installed patch; `-R` reverts all patches.
- Do not claim general package rollback. Restore the verified package and configuration state or recover from backup.
- Restore OSMAP binary and environment files as one reviewed unit.
- Re-run syntax checks before service restart, then run the full regression suite.
- Keep failed and successful evidence directories. Do not edit evidence after checksums are written.
