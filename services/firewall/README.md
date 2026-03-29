# Firewall Assets

This directory contains the public-safe PF baseline for the project.

- `etc/pf.conf.template` is the top-level PF policy
- `etc/pf.anchors/openbsd-mailstack-selfhost.template` is the mailstack anchor

Real site-specific tables, blacklist feeds, and private evidence inputs remain
outside the public repo.
