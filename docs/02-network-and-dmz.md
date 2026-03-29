# Network and DMZ Planning

## Purpose

This document explains how the public `openbsd-mailstack` repo models:

- host exposure through PF
- VPN-first administration through WireGuard
- split DNS for trusted internal and VPN users
- optional provider-backed dynamic DNS updates

The project is built around one OpenBSD mail host that may serve one domain or
many domains. Network policy is host-based, not domain-based.

## Recommended baseline

The public-safe baseline is:

- explicit router forwarding, not blanket DMZ
- public SMTP on TCP 25
- public ACME and HTTPS on TCP 80 and 443 when needed
- public WireGuard on UDP 51820
- administrative surfaces kept behind WireGuard
- SSH kept VPN-only unless the operator explicitly chooses otherwise

## Router model

Typical flow:

```text
Internet
  |
  v
Router / edge firewall
  |
  +-- explicit port forwards
  |
  v
OpenBSD mail host
  |
  +-- PF enforces host policy
  +-- WireGuard gates trusted admin access
  +-- Unbound answers local and VPN DNS
```

## DMZ guidance

Consumer routers often offer a DMZ host mode. This project does not require it.
It can be used, but the safer public baseline is still explicit forwarding plus
a strict PF policy on the host.

## Values the operator must know

Before rendering or applying the network layer, the operator should know:

- LAN interface and address
- router LAN address
- public IPv4 address
- whether public SSH is allowed
- WireGuard interface, subnet, and listen port
- whether web and admin access remain VPN-only

These values live in:

- `config/network.conf`
- `config/dns.conf`
- `config/ddns.conf`

## Public-safe outputs now provided by the repo

Phase 07 adds reusable templates and staged examples for:

- `pf.conf`
- the mailstack PF anchor
- `hostname.wg0`
- Unbound base and split-DNS include files
- a Vultr DDNS sync helper

The public repo still does not publish real peer keys, provider tokens, or live
site addresses.
