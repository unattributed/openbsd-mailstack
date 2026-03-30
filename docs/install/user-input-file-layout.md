# User Input File Layout

## Purpose

This document defines the public operator-input model for `openbsd-mailstack`.

The model has four goals:

- keep real operator values out of tracked repo content
- keep the file layout predictable
- let apply and verify scripts discover the same values consistently
- support both repo-local and host-local secret storage

## Tracked examples

These files are tracked and safe to commit:

```text
config/system.conf.example
config/network.conf.example
config/domains.conf.example
config/secrets.conf.example
config/suricata.conf.example
config/brevo-webhook.conf.example
config/sogo.conf.example
config/sbom.conf.example
config/examples/providers/vultr.env.example
config/examples/providers/brevo.env.example
config/examples/providers/virustotal.env.example
```

## Ignored repo-local files

These files are intentionally ignored by `config/.gitignore`:

```text
config/system.conf
config/network.conf
config/domains.conf
config/secrets.conf
config/suricata.conf
config/brevo-webhook.conf
config/sogo.conf
config/sbom.conf
config/local/system.conf
config/local/network.conf
config/local/domains.conf
config/local/secrets.conf
config/local/providers/vultr.env
config/local/providers/brevo.env
config/local/providers/virustotal.env
config/local/operator.env
```

Use these when you want local reproducibility inside the repo checkout without committing secrets or site-specific values.

## Protected host-local files

These files are also supported by the shared loader:

```text
/root/.config/openbsd-mailstack/system.conf
/root/.config/openbsd-mailstack/network.conf
/root/.config/openbsd-mailstack/domains.conf
/root/.config/openbsd-mailstack/secrets.conf
/root/.config/openbsd-mailstack/suricata.conf
/root/.config/openbsd-mailstack/brevo-webhook.conf
/root/.config/openbsd-mailstack/sogo.conf
/root/.config/openbsd-mailstack/sbom.conf
/root/.config/openbsd-mailstack/providers/vultr.env
/root/.config/openbsd-mailstack/providers/brevo.env
/root/.config/openbsd-mailstack/providers/virustotal.env
/root/.config/openbsd-mailstack/operator.env
```

Legacy provider paths are still accepted:

```text
/root/.config/vultr/api.env
/root/.config/brevo/brevo.env
/root/.config/virustotal/vt.env
```

## Loader precedence

`scripts/lib/operator-inputs.ksh` loads files in this order:

1. `config/system.conf`, `network.conf`, `domains.conf`, `secrets.conf`
2. `config/local/` overlays
3. `config/local/providers/*.env`
4. `~/.config/openbsd-mailstack/` files
5. `/root/.config/openbsd-mailstack/` files
6. legacy provider paths
7. files listed in `OPENBSD_MAILSTACK_EXTRA_INPUT_FILES`

Later files override earlier ones.

That means you can keep stable defaults in repo-local ignored files and still override them with host-local secrets when needed.

## Recommended usage patterns

### Pattern A, repo-local reproducible lab

Use:

```text
config/system.conf
config/network.conf
config/domains.conf
config/secrets.conf
config/local/providers/*.env
```

This works well for disposable lab systems and local QEMU testing.

### Pattern B, host-local protected production inputs

Use:

```text
config/system.conf
config/network.conf
config/domains.conf
/root/.config/openbsd-mailstack/secrets.conf
/root/.config/openbsd-mailstack/providers/*.env
```

This keeps general non-secret topology in the repo checkout and keeps secrets in root-owned protected files.

### Pattern C, fully externalized inputs

Set:

```text
OPENBSD_MAILSTACK_INPUT_ROOT=/path/to/ignored/input-root
OPENBSD_MAILSTACK_EXTRA_INPUT_FILES=/path/one:/path/two
```

This is useful when the operator wants all real inputs outside the repo tree.

## File ownership and permissions

Recommended permissions for files containing secrets:

- owner: `root`
- mode: `0600`

Repo-local non-secret files may be less strict, but keeping all operator-input files restricted is still a good default. The live core runtime renderer also forces secret-bearing rendered files and their installed copies to mode `0600`.

## Failure and prompting behavior

- if a required value is found in a loaded file, the script uses it
- if a required value is missing and interactive mode is allowed, the script can prompt
- if a required value is missing and `OPENBSD_MAILSTACK_NONINTERACTIVE=1` is set, the script fails clearly

## Practical example

A minimal repo-local setup might look like this:

```text
config/system.conf
config/network.conf
config/domains.conf
config/local/providers/vultr.env
config/local/providers/brevo.env
```

A more production-oriented setup might look like this:

```text
config/system.conf
config/network.conf
config/domains.conf
/root/.config/openbsd-mailstack/secrets.conf
/root/.config/openbsd-mailstack/suricata.conf
/root/.config/openbsd-mailstack/brevo-webhook.conf
/root/.config/openbsd-mailstack/sogo.conf
/root/.config/openbsd-mailstack/sbom.conf
/root/.config/openbsd-mailstack/providers/vultr.env
/root/.config/openbsd-mailstack/providers/brevo.env
```
