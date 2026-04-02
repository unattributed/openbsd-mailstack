# Phase 01, network and external access

## Goal

Build the exposure model first, then render the public-safe baseline assets.

## What Phase 01 now does

The public repo no longer stops at a router checklist alone. Phase 01 now:

- validates the network and exposure model
- saves network, DNS, and DDNS settings when requested
- renders live PF, WireGuard, Unbound, and DDNS assets under `.work/network-exposure/rootfs/`, while leaving `services/generated/rootfs/` as the tracked sanitized example reference
- points operators at the install and verify helpers for later host-side use

## Inputs

- `config/network.conf`
- `config/dns.conf`
- `config/ddns.conf`
- `config/local/providers/vultr.env`, or another supported ignored provider file

## Success criteria

- the network inputs are valid
- staged rendered assets exist
- the host exposure model is coherent
- VPN-only admin and web policy is explicit
