# Generated Assets

`services/generated/` is the tracked, public-safe generated asset area for the repository.

## `services/generated/rootfs/`

This tree is a sanitized example render tree that documents expected filesystem layout and file shape.

Some files in this example tree use secret-bearing filenames, but they contain placeholder values only. Do not treat this path as the live operator render destination.

## Live operator render paths

The live operator render paths are now gitignored under `.work/` by default:

- core runtime, `.work/runtime/rootfs/`
- network exposure, `.work/network-exposure/rootfs/`
- DNS and identity guidance, `.work/identity/`
- advanced optional assets, `.work/advanced/rootfs/`
- SBOM and host inventory reports, `.work/advanced/sbom/`

These live trees may contain real passwords, hashes, hostnames, domains, IP addresses, application inventory, vulnerability scan results, and other deployment-specific values. They are intended to remain local to the operator checkout.
