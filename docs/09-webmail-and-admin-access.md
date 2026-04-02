# Webmail and administrative access

## Purpose

This document explains how the public `openbsd-mailstack` project prepares the
webmail and administrative access layer for the MVP stage.

The public baseline for this phase is strict:

- Roundcube is used for webmail during the MVP stage
- PostfixAdmin is used for mailbox and domain administration
- Rspamd UI can be exposed for administrative review
- all three are restricted to the WireGuard subnet
- nginx is used as the policy enforcement point

## Why this matters

This keeps the public project aligned with a stricter security model while the
broader platform remains in MVP and under active validation.

The key idea is:

- public SMTP can remain exposed as required
- administrative and webmail surfaces do not need to be public
- web access is protected by both TLS and network restriction

## Public access baseline

Use this pattern:

```sh
MAIL_HOSTNAME="mail.example.com"
PRIMARY_DOMAIN="example.com"

ENABLE_WIREGUARD="yes"
WIREGUARD_INTERFACE="wg0"
WIREGUARD_SUBNET="10.44.0.0/24"
WEB_VPN_ONLY="yes"

ROUNDCUBE_ENABLED="yes"
ROUNDCUBE_WEB_HOSTNAME="mail.example.com"
POSTFIXADMIN_WEB_HOSTNAME="mail.example.com"
RSPAMD_UI_HOSTNAME="mail.example.com"
```

In that model:

- nginx listens for the web applications
- nginx restricts access to the WireGuard subnet
- Roundcube is the temporary webmail layer until the OSMAP project is ready
- PostfixAdmin and Rspamd UI stay administrative and VPN only

## What this phase expects from you

Before running Phase 08, you should know:

- whether WireGuard is enabled
- the WireGuard subnet
- whether web surfaces should remain VPN only
- whether Roundcube should be enabled
- the hostname to use in nginx server blocks
- the TLS certificate paths already established in Phase 06

These values can be placed in:

- `config/network.conf`
- `config/system.conf`

If they are missing, the apply script can prompt for them unless noninteractive
mode is enabled.

## What Phase 08 changes

The apply script is intentionally conservative. It prepares the repo workflow by:

- validating WireGuard and web access settings
- validating hostnames and TLS file paths
- confirming nginx-related commands exist
- generating public-safe nginx location and server fragments
- generating Roundcube and PostfixAdmin access examples
- generating an Rspamd UI access example
- writing an access summary file for operator review

The generated files are helper artifacts. They are intended to guide later live
deployment on OpenBSD 7.8.

## Outputs created by Phase 08

Phase 08 now uses the shared core runtime renderer and phase-scoped verification.

Review the live operator render under `.work/runtime/rootfs/`, especially:

- `.work/runtime/rootfs/var/www/roundcubemail/config/config.inc.php`
- `.work/runtime/rootfs/var/www/postfixadmin/config.local.php`
- `.work/runtime/rootfs/etc/nginx/sites-available/main.conf`
- `.work/runtime/rootfs/etc/nginx/sites-available/main-ssl.conf`
- `.work/runtime/rootfs/etc/nginx/templates/rspamd.tmpl`

Use `services/generated/rootfs/` only as the tracked sanitized example reference.

## Verification

The verify script checks:

- WireGuard and VPN-only settings are valid
- required commands exist
- generated helper files exist when expected

## Recommended usage

For experienced users:

- pre-fill the config files
- run the phase in noninteractive mode
- review the generated helper files before moving on

For newer users:

- run the script interactively
- answer the prompts carefully
- use the generated fragments as your implementation guide

## Next step

After Phase 08 succeeds, the next logical phase is DNS, domain policy, and mail
identity publishing, including DKIM, SPF, DMARC, and related records.


## Phase 02 runtime note

This phase now uses the shared core runtime renderer and installer. Review `docs/configuration/core-runtime-and-config-wiring.md`, then run `./scripts/install/render-core-runtime-configs.ksh` to stage the live operator runtime tree under `.work/runtime/rootfs/`. Use `services/generated/rootfs/` only as the tracked sanitized example reference.
