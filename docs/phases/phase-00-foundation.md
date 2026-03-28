# Phase 00, Foundation

## Purpose

Phase 00 establishes the baseline operating environment for the public `openbsd-mailstack` project on **OpenBSD 7.8**.

This phase does not deploy the full mail stack yet. It prepares the host so later phases can safely configure services such as Postfix, Dovecot, Rspamd, nginx, Roundcube, DKIM, TLS, and multi-domain mail routing.

This phase focuses on:

- confirming the host is running OpenBSD 7.8
- collecting the core settings the rest of the project needs
- validating network and identity information
- checking that the host has the expected command-line tools
- checking that the filesystem and swap state are reasonable
- checking that the machine is ready for later mail phases

## Who this phase is for

This phase is required for all users of the project.

It is especially important for:

- first-time users who want guided setup
- administrators preparing a new OpenBSD 7.8 host
- advanced users who want repeatable, config-driven deployment

## What information you need before starting

Before running this phase, gather the following information:

- the hostname your users will connect to, for example `mail.example.com`
- your primary mail domain, for example `example.com`
- any additional hosted domains, for example `example.net` and `example.org`
- the administrator email address for the system, for example `ops@example.com`
- the public IPv4 address of the server
- the LAN IPv4 address of the server
- the LAN and WAN interface names on OpenBSD, for example `em0` and `em1`
- whether you plan to use WireGuard later

If you do not know all of these values yet, the script can prompt you for missing values during execution.

## How user customization works

This project supports two ways to provide environment-specific values.

### Method 1, configuration files

This is the recommended method for repeatable deployments.

Copy the example files and edit them:

```sh
cp config/system.conf.example config/system.conf
cp config/network.conf.example config/network.conf
cp config/domains.conf.example config/domains.conf
cp config/secrets.conf.example config/secrets.conf
```

Then edit the copied files with your real values.

### Method 2, interactive prompts

If required values are missing, the Phase 00 apply script can ask for them during execution.

This helps users who are less comfortable editing configuration files first.

The script validates what you enter and stops with a clear error if a value is missing or invalid.

### Recommended approach

- use config files for reproducibility
- use prompts for first-time setup or when testing
- never edit the scripts themselves to customize values

## Multi-domain usage notes

This project is designed to support multiple domains.

Use the files like this:

- `config/system.conf` defines system-wide identity such as `MAIL_HOSTNAME`
- `config/domains.conf` defines the hosted domain set using:
  - `PRIMARY_DOMAIN`
  - `DOMAINS`

Example:

```sh
MAIL_HOSTNAME="mail.example.com"
PRIMARY_DOMAIN="example.com"
DOMAINS="example.com example.net example.org"
```

In that example:

- `mail.example.com` is the host users connect to
- `example.com` is the main domain for the deployment
- `example.net` and `example.org` are additional mail domains hosted on the same stack

Later phases can use the `DOMAINS` list to generate domain-specific guidance, DKIM material, and mail routing configuration.

## What this phase changes

The apply script for Phase 00 is intentionally conservative.

It does the following:

- loads your config values
- prompts for missing values if interactive mode is allowed
- validates key settings
- writes local config files if you choose to save your answers
- checks that the host is OpenBSD 7.8
- checks that required commands exist
- checks basic filesystem and swap readiness

This phase does not install or configure the mail services themselves.

## Preconditions

Before running this phase:

- the host must already be installed with OpenBSD 7.8
- you must have shell access to the host
- you should run the script from the repository root
- you should have permission to use `doas` for checks that require elevation

## Run the phase

From the project root:

```sh
doas ./scripts/phases/phase-00-apply.ksh
```

If you want to avoid prompts and use config files only:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-00-apply.ksh
```

## Verify the phase

Run:

```sh
./scripts/phases/phase-00-verify.ksh
```

If your config files are incomplete and you still want verification to prompt for missing values:

```sh
OPENBSD_MAILSTACK_NONINTERACTIVE=0 ./scripts/phases/phase-00-verify.ksh
```

## What success looks like

A successful Phase 00 result means:

- the host is confirmed as OpenBSD 7.8
- your hostname, domain, domains list, email, and IP settings are present and valid
- required commands are available
- root filesystem and swap checks pass
- the host is ready for the next mail stack phase

## Troubleshooting

### The script says the OpenBSD version is wrong

This public release supports OpenBSD 7.8 only.

Check the version:

```sh
uname -r
```

### The script says a value is missing

Either:

- add the missing value to the appropriate file in `config/`, or
- rerun the phase without noninteractive mode and answer the prompt

### The script says a domain or hostname is invalid

Review the corresponding config value and correct it. Use normal DNS hostnames such as `mail.example.com` and normal domains such as `example.net`.

### The verify script reports a missing command

Install the required package or confirm the expected base command exists before moving on to the next phase.

## Audience notes

### If you are new to self-hosting

Start with the example config files and let the script prompt you for anything you missed.

### If you are already comfortable with OpenBSD

Pre-fill the config files, then run this phase in noninteractive mode for deterministic results.

### If you want to automate deployment later

Use config files only, commit only the `.example` files, and keep your real `config/*.conf` files local and private.

## Next phase

After Phase 00 succeeds, the next step is the network and external access phase, where you define:

- LAN and WAN behavior
- public router or DMZ setup requirements
- TLS preconditions
- later service exposure requirements
