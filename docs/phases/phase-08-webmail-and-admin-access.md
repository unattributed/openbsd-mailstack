# Phase 08, webmail and administrative access

## Purpose

Phase 08 prepares the VPN-only webmail and administrative access model for the
public `openbsd-mailstack` project.

This phase defines how nginx, Roundcube, PostfixAdmin, and Rspamd UI should
align during the MVP stage:

- Roundcube is the interim webmail interface
- PostfixAdmin remains the administrative interface
- Rspamd UI remains administrative
- all web surfaces are restricted to the WireGuard subnet

## Who this phase is for

This phase is required for users who want a secure MVP-stage access model for:

- webmail
- mailbox administration
- filtering interface review

It is especially relevant for users who want to avoid public HTTPS exposure for
these surfaces until the wider project has matured and been fully tested.

## Information you need before starting

You should have:

- a valid `MAIL_HOSTNAME`
- a valid `PRIMARY_DOMAIN`
- `ENABLE_WIREGUARD="yes"`
- a valid `WIREGUARD_INTERFACE`
- a valid `WIREGUARD_SUBNET`
- `WEB_VPN_ONLY="yes"`
- a valid `ROUNDCUBE_ENABLED` choice
- valid TLS certificate paths from Phase 06

## How user customization works

This phase supports two ways to provide values.

### Method 1, configuration files

Recommended for repeatable deployments.

Edit:

- `config/network.conf`
- `config/system.conf`

### Method 2, interactive prompts

If required values are missing, the apply script can prompt for them.

This is useful for first-time users, but config files remain the better long-term
option because they make later phases easier and more deterministic.

Do not edit the scripts themselves to change deployment values.

## Access model

The public repo enforces this MVP model:

- Roundcube, PostfixAdmin, and Rspamd UI remain VPN only
- nginx restricts these surfaces to the WireGuard subnet
- Roundcube remains the interim webmail layer until OSMAP moves beyond MVP and
  has been fully tested

Example:

```sh
ENABLE_WIREGUARD="yes"
WIREGUARD_SUBNET="10.44.0.0/24"
WEB_VPN_ONLY="yes"
ROUNDCUBE_ENABLED="yes"
MAIL_HOSTNAME="mail.example.com"
```

## Preconditions

Before running this phase:

- Phase 00 through Phase 07 should be complete
- nginx should be installed
- WireGuard should be planned and enabled
- TLS paths from Phase 06 should already be defined

## What the script changes

The apply script can:

- validate VPN-only web access inputs
- validate hostname and TLS settings
- create nginx server fragments for Roundcube, PostfixAdmin, and Rspamd UI
- create service-specific access summaries
- write a web access summary for review

This phase does not claim to fully deploy the live web applications by itself. It
prepares a clean, public-repo-friendly baseline for that deployment.

## Run the phase

From the project root:

```sh
doas ./scripts/phases/phase-08-apply.ksh
```

For deterministic config-only execution:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-08-apply.ksh
```

If you want the script to save prompted values back into config files, use:

```sh
doas env SAVE_CONFIG=yes ./scripts/phases/phase-08-apply.ksh
```

## Verify the phase

Run:

```sh
./scripts/phases/phase-08-verify.ksh
```

## What success looks like

A successful result means:

- VPN-only settings are valid
- required commands are available
- helper files were generated in `services/nginx/`, `services/roundcube/`,
  `services/postfixadmin/`, and `services/rspamd/`
- the repo is ready for the next phase

## Troubleshooting

### The script says WireGuard must be enabled

For the public MVP access baseline, `ENABLE_WIREGUARD` must be `yes`.

### The script says WEB_VPN_ONLY must be yes

For the public MVP access baseline, web surfaces remain VPN only.

### The script says a hostname is invalid

Use a normal hostname such as `mail.example.com`.

### The verify script warns that nginx is missing

Install the expected nginx package and rerun the verify step before continuing.

## Audience notes

### If you are new to self-hosting

Use the prompts, then review the generated helper files so you understand how
VPN-only webmail and administrative access are enforced.

### If you are already comfortable with OpenBSD mail systems

Pre-fill the config files, run the phase in noninteractive mode, and treat the
generated helper outputs as review artifacts before your live deployment step.

## Next phase

After Phase 08 succeeds, continue to the DNS and identity publishing phase.


## Phase 02 runtime note

This phase now uses the shared core runtime renderer and installer. Review `docs/configuration/core-runtime-and-config-wiring.md`, then run `./scripts/install/render-core-runtime-configs.ksh` to stage the live operator runtime tree under `.work/runtime/rootfs/`. Use `services/generated/rootfs/` only as the tracked sanitized example reference.
