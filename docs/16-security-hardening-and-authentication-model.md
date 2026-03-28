# Security hardening and authentication model

## Purpose

This phase extends the public `openbsd-mailstack` project with a security
hardening and authentication baseline.

The focus is on:

- authentication boundary design
- password handling guidance
- staged second-factor planning
- Dovecot and Roundcube hardening notes
- Thunderbird and other IMAP client reality constraints
- public-safe authentication policy artifacts

## Why this matters

A secure mail platform needs a clear authentication model, not just working
services.

This phase helps operators define:

- where primary authentication occurs
- what can realistically support second factor controls
- how to stage stronger authentication over time
- how to keep the MVP secure without promising unsupported client behavior

## Public baseline

The public baseline for this phase is conservative:

- strong unique passwords are required
- VPN-only access remains in place for web and admin surfaces
- Roundcube remains the interim webmail interface
- Dovecot authentication remains the IMAP and submission credential authority
- second-factor planning is documented in stages rather than forced blindly

## Important compatibility reality

Traditional mail clients such as Thunderbird typically authenticate to IMAP and
submission using username and password. That means universal TOTP enforcement at
the mail protocol layer is not a simple drop-in feature for standard clients.

Because of that, the public baseline is:

- do not claim universal TOTP support for all mail clients by default
- document staged hardening options
- keep Roundcube and admin surfaces behind WireGuard during MVP
- use stronger password and account policy now
- evaluate app-password or gateway-based second-factor designs later

## Hardening stages

### Stage 1, baseline hardening

- require strong unique passwords
- lock down VPN-only surfaces
- reduce account sprawl
- keep TLS mandatory
- maintain mail filtering and abuse controls
- review service logs regularly

### Stage 2, web and admin second factor

This is the first realistic second-factor target because web flows are easier to
protect than legacy mail protocols.

Targets:

- Roundcube, if a supported second-factor approach is validated
- PostfixAdmin
- any future administrative web surfaces

### Stage 3, client-aware advanced auth

Possible future paths:

- app-password model
- identity proxy model
- gateway-enforced second factor
- alternative auth architecture beyond basic IMAP password flows

These should be treated as advanced design work, not MVP assumptions.

## Outputs in this phase

This phase generates example artifacts for:

- authentication policy guidance
- password policy guidance
- staged second-factor roadmap
- Dovecot and Roundcube hardening notes
- phase summary

## Next step

After this phase, the project is ready for a full public consistency and
documentation audit, or for deeper hardening phases focused on secrets handling,
identity integration, or enforcement controls.
