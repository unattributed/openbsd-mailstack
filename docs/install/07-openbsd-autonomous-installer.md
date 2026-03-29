# OpenBSD Autonomous Installer

## Purpose

This document explains how to build a custom OpenBSD autoinstall pack for `openbsd-mailstack`.

The public autonomous installer layer is intended for operators who want to:

- automate OpenBSD installation
- preload first-boot bootstrap logic
- avoid hardcoded assumptions such as `foo` or `/home/foo`
- generate a reusable install pack for lab or real hardware

## What this layer provides

The public autonomous installer directory lives at:

- `maint/openbsd-autonomous-installer/`

It provides:

- profile example file
- renderer script
- lab and real install.conf generation
- site78.tgz generation
- first-boot bootstrap template
- local HTTP serving helper
- disklabel template

## User-supplied variables

At minimum, you should set:

- `LAN_IF_DEFAULT`
- `LAN_NET_DEFAULT`
- `HOST_IP_DEFAULT`
- `PARROT_PUBKEY`
- `OPERATOR_USER`

The installer layer also derives:

- `OPERATOR_HOME`
- `MAILSTACK_REPO_CLONE_URL`
- host and domain naming
- OpenBSD install answer file content

## Why this matters

The original prototype used `foo` and `/home/foo` directly. The public project must not assume that.

The autonomous installer renderer fixes that by allowing the operator to declare:

- the username
- the home path
- the SSH public key
- the bootstrap network assumptions

## Main files

- `installer-profile.example.env`
- `render-installer-pack.ksh`
- `install.conf.78.lab.template`
- `install.conf.78.real.template`
- `site78_root/install.site.template`
- `site78_root/root/phase00-firstboot.sh.template`
- `serve-autoinstall.sh`
- `disklabel-root-swap.template`

## Typical workflow

### 1. Create a local profile

```sh
cp maint/openbsd-autonomous-installer/installer-profile.example.env \
   maint/openbsd-autonomous-installer/installer-profile.local.env
```

### 2. Edit the local profile

Set at least:

- `OPERATOR_USER`
- `PARROT_PUBKEY`
- `LAN_IF_DEFAULT`
- `LAN_NET_DEFAULT`
- `HOST_IP_DEFAULT`

### 3. Render the installer pack

```sh
ksh maint/openbsd-autonomous-installer/render-installer-pack.ksh \
  --profile maint/openbsd-autonomous-installer/installer-profile.local.env
```

### 4. Serve the generated pack over HTTP

```sh
sh maint/openbsd-autonomous-installer/serve-autoinstall.sh \
  /home/foo/Workspace/openbsd-mailstack/maint/openbsd-autonomous-installer/build/default 8000
```

### 5. Boot OpenBSD and choose autoinstall

Use either the generated lab or real install response file.

## Output layout

The renderer writes to:

```text
maint/openbsd-autonomous-installer/build/<profile-name>/
```

Generated outputs include:

- `install.conf.78.lab`
- `install.conf.78.real`
- `site78.tgz`
- `ACCOUNT-READINESS.md`

## Design notes

- the public baseline now uses `OPERATOR_USER` and `OPERATOR_HOME`
- no file in this layer should assume `/home/foo`
- no file in this layer should assume the operator is named `foo`
- all live secrets remain outside Git

## Security notes

- do not place real provider credentials in tracked files
- do not place private keys in the rendered public pack
- keep your real profile file local and untracked
