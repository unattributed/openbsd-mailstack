# DR site provisioning

## Purpose

This document describes how to provision the public-safe DR site that ships with `openbsd-mailstack`.

The DR site is an internal static portal, intended for a trusted control plane. It is not a telemetry surface. It is a repo-managed operator surface for restore guidance and DR context.

## Inputs

Populate `config/dr-site.conf` or another supported ignored input path with:

- `DR_SITE_SERVER_NAME`
- `DR_SITE_OPERATOR_EMAIL`
- `DR_SITE_PUBLISH_ROOT`
- `DR_SITE_TEMPLATE_ROOT`
- `DR_SITE_LOCATION_TEMPLATE`
- `DR_SITE_ALLOW_TEMPLATE`
- `DR_SITE_NGINX_SERVER_CONF`
- `DR_SITE_PATCH_SERVER_CONF`

## Dry run

```sh
cd /home/foo/Workspace/openbsd-mailstack
doas ksh scripts/install/install-dr-site-assets.ksh --dry-run
```

## Apply

```sh
cd /home/foo/Workspace/openbsd-mailstack
doas ksh scripts/install/install-dr-site-assets.ksh --apply
```

## What the installer does

- renders the static pages from `maint/dr-site/htdocs/`
- copies them into the configured publish root
- renders the nginx location block template
- optionally patches the configured nginx server file when `DR_SITE_PATCH_SERVER_CONF=yes`
- runs `nginx -t` after apply when nginx is available
- stores backups of replaced files under `DR_SITE_BACKUP_ROOT`

## Recommended rollout

1. dry-run the installer
2. inspect the rendered paths and the optional nginx patch target
3. apply the installer
4. reload nginx manually after review
5. verify `https://<dr-site-host>/dr/` from an allowed management address

## Verification

```sh
ksh scripts/verify/verify-dr-site-plan.ksh
curl -k -I https://127.0.0.1/dr/
```

## DR Host Bootstrap

The DR portal is only one part of the standby site. To bootstrap the standby host
layout itself, use `docs/install/15-dr-host-bootstrap.md` and
`scripts/install/provision-dr-site-host.ksh`.
