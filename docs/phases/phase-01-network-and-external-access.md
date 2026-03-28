# Phase 01, Network and External Access

## Purpose

Phase 01 defines and validates the external access model for the public
`openbsd-mailstack` project.

This phase is where the user describes how the mail host will be reached from
the Internet and how administrative access will be restricted.

This phase focuses on:

- LAN and WAN interface definitions
- LAN and public IP addressing
- router LAN address
- whether the router uses a DMZ host or explicit port forwarding
- which public TCP and UDP ports are required
- whether SSH stays VPN-only or becomes publicly reachable
- how one server can safely support multiple mail domains

This phase does not configure your physical router for you. Instead, it creates
and validates the information you need so you can configure the router correctly
and continue with later service phases.

---

## Who this phase is for

This phase is required for all users.

It is especially important for:

- users deploying the project behind a home or office router
- users with one public IP and one internal OpenBSD host
- users hosting multiple mail domains on one server
- users who want a VPN-first administrative model

---

## Information you need before starting

Before you run this phase, you should know:

- your LAN interface name, for example `em0`
- your WAN interface name, for example `em1`
- the LAN IPv4 address you want the OpenBSD server to use
- the LAN prefix length, for example `24`
- your router LAN address, for example `192.168.1.1`
- your public IPv4 address
- whether your router supports and uses a DMZ host
- whether you want WireGuard exposed publicly
- whether you want SSH exposed publicly, or only through WireGuard
- the list of mail domains that this server will host

If you do not know all of these values yet, the script can prompt you for any
missing values.

---

## How user customization works

This project supports two ways to provide your network and exposure settings.

### Method 1, configuration files

This is the recommended method for repeatable deployments.

Edit these files:

- `config/system.conf`
- `config/network.conf`
- `config/domains.conf`

Important:

- `config/system.conf` contains host-wide identity values
- `config/network.conf` contains routing, NAT, DMZ, WireGuard, and exposure values
- `config/domains.conf` contains the complete list of hosted domains

### Method 2, interactive prompts

If required values are missing, the apply script can prompt you for them.

This is useful for first-time users and for testing.

### Recommended approach

- use config files for long-term reproducibility
- use prompts for first-time setup or when a value is missing
- do not edit the scripts to insert environment-specific data

---

## Multiple domain guidance

This phase is multi-domain aware.

That means:

- the same host can serve many domains
- the same public IP and router policy can support many domains
- later DNS and DKIM phases will handle domain-specific records

Example:

- mail host: `mail.example.com`
- primary domain: `example.com`
- hosted domains: `example.com example.net example.org`

In this model, the network policy remains host-based. You do not normally need
separate router forwarding rules for each domain.

---

## What this phase changes

The apply script for Phase 01 is intentionally conservative.

It does the following:

- loads and validates network and exposure settings
- prompts for missing values if interactive mode is allowed
- normalizes the public TCP and UDP port lists
- writes updated network and domain configuration if you choose to save values
- prints a router and DMZ checklist based on your settings
- checks that required OpenBSD commands exist
- checks that the LAN and WAN interfaces exist on the host

This phase does not modify your router, your external firewall, or your DNS.

---

## Preconditions

Before running this phase:

- Phase 00 should already pass
- the host must already be installed with OpenBSD 7.8
- the OpenBSD server should already have the intended network interfaces present
- you should know whether your router will use DMZ or explicit port forwarding

---

## Run the phase

From the project root:

```sh
./scripts/phases/phase-01-apply.ksh
```

If you want to avoid prompts and use config files only:

```sh
OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-01-apply.ksh
```

If you want the script to save prompted values back into your config files:

```sh
SAVE_CONFIG=yes ./scripts/phases/phase-01-apply.ksh
```

---

## Verify the phase

Run:

```sh
./scripts/phases/phase-01-verify.ksh
```

The verify script reads the same config values and checks that they are valid,
consistent, and appropriate for later phases.

---

## What success looks like

A successful Phase 01 result means:

- LAN and WAN interface names are valid
- the LAN address and router values are valid
- the public TCP and UDP port lists are valid
- the host exposure model is internally consistent
- the project has a clear router configuration plan
- the design remains suitable for one or many hosted domains

---

## Troubleshooting

### The script says an interface name is invalid or missing

Use `ifconfig` to confirm the real interface names on your OpenBSD host.

### The script says a port list is invalid

Port lists must be space-separated numeric ports, for example:

- `25 80 443`
- `51820`

Do not use commas.

### The script warns about public SSH

That warning is intentional. Public SSH is possible, but a VPN-first model is
recommended for administrative access.

### The script says DMZ mode conflicts with the target IP

Make sure the DMZ target host matches the LAN IP of the OpenBSD mail server.

---

## Audience notes

### If you are new to self-hosting

Use explicit port forwarding rather than router DMZ unless you clearly understand
how your router handles DMZ traffic.

### If you are already comfortable with OpenBSD and routers

Pre-fill the config files and run this phase in noninteractive mode.

### If you will host multiple domains

Make sure all hosted domains are listed in `config/domains.conf`, but do not try
to solve DNS or DKIM in this phase. That comes later.

---

## Next phase

After Phase 01 succeeds, the next step is the data and service foundation for
mail identity storage and service dependency planning.
