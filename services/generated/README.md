# Generated Assets

`services/generated/` is the tracked, public-safe generated asset area for the repository.

## `services/generated/rootfs/`

This tree is a sanitized example render tree that documents expected filesystem layout and file shape.

Some files in this example tree use secret-bearing filenames, but they contain placeholder values only. Do not treat this path as the live operator render destination.

## Live operator render path

`./scripts/install/render-core-runtime-configs.ksh` now renders live operator output into `.work/runtime/rootfs/` by default.

That live tree may contain real passwords, hashes, hostnames, IP addresses, and other deployment-specific values. It is gitignored and intended to remain local to the operator checkout.
