# Network and DMZ Planning

## Purpose

This document explains how to prepare the network side of an `openbsd-mailstack`
deployment before later phases install public services.

The mail host can support one domain or many domains, but the network design is
built around the **server**, not around each domain individually.

In the common case, you need:

- one OpenBSD host
- one router or firewall that controls inbound Internet traffic
- one public IPv4 address
- one LAN IPv4 address for the mail host
- a defined policy for which services are public and which stay VPN-only

---

## What this document covers

This document helps you decide:

- which IP addresses the server should use
- whether to use a DMZ or simple port forwarding
- which ports must be reachable from the Internet
- which administrative services should stay behind WireGuard
- how this works when hosting multiple mail domains

---

## The basic model

A typical layout looks like this:

```text
Internet
  |
  v
Router / Firewall
  |
  +-- public IP
  |
  +-- NAT, port forwarding, or DMZ rules
  |
  v
OpenBSD mail host on the LAN
```

The OpenBSD server usually has a private LAN address such as `192.168.1.44`, and
your router handles inbound Internet traffic by forwarding required ports to that
host.

---

## DMZ versus port forwarding

### Option 1, port forwarding

This is the more controlled option for most users.

You forward only the ports required by the project to the OpenBSD mail host.

Typical public ports are:

- TCP 25, inbound SMTP
- TCP 80, ACME HTTP validation when needed
- TCP 443, HTTPS for webmail or published web endpoints
- UDP 51820, WireGuard

### Option 2, router DMZ

Some consumer routers support a DMZ host mode where unsolicited inbound traffic
is sent to one internal IP address.

This can work, but it is broader than targeted port forwarding. If you use DMZ
mode, you should still keep the OpenBSD firewall policy strict and expose only
what the host is designed to accept.

---

## SSH exposure guidance

For this project, a VPN-first administrative model is recommended.

That means:

- keep SSH off the public Internet if possible
- use WireGuard for admin access
- publish only the services that must be public

Public SSH is possible, but it increases exposure and should be a conscious
choice, not a default.

---

## How multiple domains affect networking

Multiple domains do **not** usually require separate routers, separate LAN IPs,
or separate public port forwarding policies.

For a typical deployment:

- one server can host many domains
- one public IP can receive mail for many domains
- one router forwarding policy can support all those domains
- the difference between domains is handled later through DNS and mail routing

Example:

- mail host: `mail.example.com`
- hosted domains: `example.com`, `example.net`, `example.org`

In that design:

- SMTP still comes to the same host
- HTTPS still goes to the same host
- WireGuard still goes to the same host
- each domain later gets its own DNS records and DKIM configuration

---

## Values the user must know

Before running Phase 01, the user should know:

- LAN interface name, for example `em0`
- WAN interface name, for example `em1`
- LAN IPv4 address of the mail server
- LAN prefix length, for example `24`
- router LAN address
- public IPv4 address
- whether DMZ mode is used
- whether WireGuard is used
- whether SSH should be public or VPN-only
- which domains will be hosted

---

## Recommended baseline

For most users, the safest starting point is:

- no router DMZ
- explicit port forwards only
- public TCP 25, 80, and 443
- public UDP 51820 for WireGuard
- SSH kept VPN-only
- admin interfaces kept VPN-only

---

## Relation to later phases

This planning document prepares the inputs used by:

- Phase 01, network and external access
- later TLS and ACME phases
- later DNS and DKIM phases
- later webmail and admin exposure decisions

A correct network model early in the project makes the rest of the deployment
much easier.
