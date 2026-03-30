# Core runtime and config wiring

Phase 02 adds a shared runtime rendering model.

## Source templates

The core service templates live under `services/<service>/` and are sanitized for public use.

## Tracked example rootfs

`services/generated/rootfs/` remains the tracked sanitized example tree.

Some files in that example tree use secret-bearing filenames, but they only contain placeholder values for public-safe documentation.

## Live operator rootfs

Run:

```sh
./scripts/install/render-core-runtime-configs.ksh
```

By default this creates a live operator filesystem tree under `.work/runtime/rootfs/`.

That live tree may contain real credentials and other deployment-specific values. It is gitignored and should remain local to the operator checkout. Secret-bearing rendered files are forced to mode `0600` during render and re-enforced during install.

Override the default live render destination when needed:

```sh
OPENBSD_MAILSTACK_CORE_RENDER_ROOT=/tmp/openbsd-mailstack-runtime/rootfs ./scripts/install/render-core-runtime-configs.ksh
```

## Install into a target root

```sh
doas ./scripts/install/install-core-runtime-configs.ksh
```

For a lab or alternate root:

```sh
./scripts/install/install-core-runtime-configs.ksh --target-root /tmp/openbsd-mailstack-root
```

To install from a non-default live render location:

```sh
./scripts/install/install-core-runtime-configs.ksh --render-root /tmp/openbsd-mailstack-runtime/rootfs --target-root /tmp/openbsd-mailstack-root
```
