# Phase 00, foundation

## Purpose

Phase 00 prepares the public `openbsd-mailstack` project foundation, config model,
and first-run operator baseline.

This phase assumes the operator is starting from a clean OpenBSD 7.8 host and is
preparing the local repository configuration needed for later phases.

## External Prerequisites

Before running this phase, you MUST complete:

- `docs/install/02-vultr-account-and-api-setup.md`

This ensures:

- DNS authority is established
- the domain can later be delegated correctly
- a Vultr account already exists
- the Vultr API key already exists for future DNS workflows
- the API key is stored securely outside the repository
- secrets are handled securely from the start

## Who this phase is for

This phase is required for every deployment.

It is especially relevant for:

- first-time operators
- users preparing a new public mail host
- users adapting the framework to one or more hosted domains

## Information you need before starting

You should have:

- a public mail hostname, such as `mail.example.com`
- a primary domain, such as `example.com`
- an administrative email address
- a clear decision on single-domain or multi-domain operation
- completion of the external prerequisite documents

## How user customization works

This phase supports two ways to provide values.

### Method 1, configuration files

Recommended for repeatable deployments.

Edit:

- `config/system.conf`
- `config/network.conf`
- `config/domains.conf`
- `config/secrets.conf`

### Method 2, interactive prompts

If required values are missing, the apply script can prompt for them.

This is useful for first-time users, but config files remain the better long-term
option because they make later phases easier and more deterministic.

Do not edit the scripts themselves to change deployment values.

## Preconditions

Before running this phase:

- external prerequisite documentation should be completed
- the host should be OpenBSD 7.8
- the repository should be present locally
- the operator should know the target hostname and primary domain

## What the script changes

The apply script can:

- validate baseline config inputs
- create or update local config files when requested
- prepare the project for later installation phases
- verify foundation-level assumptions

This phase does not claim to install the full mail stack. It only prepares the
public repo and operator environment for those phases.

## Run the phase

From the project root:

```sh
doas ./scripts/phases/phase-00-apply.ksh
```

For deterministic config-only execution:

```sh
doas env OPENBSD_MAILSTACK_NONINTERACTIVE=1 ./scripts/phases/phase-00-apply.ksh
```

If you want the script to save prompted values back into config files, use:

```sh
doas env SAVE_CONFIG=yes ./scripts/phases/phase-00-apply.ksh
```

## Verify the phase

Run:

```sh
./scripts/phases/phase-00-verify.ksh
```

## What success looks like

A successful result means:

- the basic config model is valid
- required baseline inputs exist
- the repository is ready for the next phase

## Next phase

After Phase 00 succeeds, continue to the network and external access phase.
