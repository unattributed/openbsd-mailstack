# Core runtime and config wiring

Phase 02 adds a shared runtime rendering model.

## Source templates

The core service templates live under `services/<service>/` and are sanitized for public use.

## Rendered rootfs

Run:

```sh
./scripts/install/render-core-runtime-configs.ksh
```

This creates a staged filesystem tree under `services/generated/rootfs/`.

## Install into a target root

```sh
doas ./scripts/install/install-core-runtime-configs.ksh
```

For a lab or alternate root:

```sh
./scripts/install/install-core-runtime-configs.ksh --target-root /tmp/openbsd-mailstack-root
```
