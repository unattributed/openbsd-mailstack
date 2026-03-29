# Phase crosswalk

## Current public migration map

| Public phase | Current state | Evidence in public repo |
|---|---|---|
| Phase 00, foundation | materially usable | apply and verify scripts, shared loader, operator input model |
| Phase 01, network and external access | materially usable | PF, WireGuard, Unbound, and DDNS templates and helpers |
| Phase 02, MariaDB baseline | materially usable | MariaDB templates, installer, verifier |
| Phase 03, PostfixAdmin and SQL wiring | materially usable | PostfixAdmin templates, installer, verifier |
| Phase 04, Postfix core and SQL integration | materially usable | Postfix templates, installer, verifier |
| Phase 05, Dovecot auth and mailbox delivery | materially usable | Dovecot templates, installer, verifier |
| Phase 06, TLS and certificate automation | materially usable | public-safe TLS guidance and phase scripts |
| Phase 07, filtering and anti-abuse | materially usable | Rspamd, Redis, ClamAV, FreshClam assets and phase scripts |
| Phase 08, webmail and admin access | materially usable | Roundcube, nginx, admin path assets and phase scripts |
| Phase 09, DNS and identity publishing | materially usable | DNS, DDNS, and identity publication guidance |
| Phase 10, operations and resilience | materially usable | post-install checks and operator workflow scripts |
| Phase 11, backup and disaster recovery | materially usable | backup, restore, DR portal, and phase scripts |
| Phase 12, advanced backup security and integrity | materially usable | backup verification, archive protection, and scheduling helpers |
| Phase 13, off-host replication and restore testing | materially usable | replication and restore drill workflows, including QEMU restore helper |
| Phase 14, monitoring and reporting baseline | materially usable | monitoring renderers, health checks, nginx, cron, and newsyslog helpers |
| Phase 15, security hardening and authentication model | partial | useful docs are present, automation remains limited |
| Phase 16, secrets handling and key material management | partial | useful docs are present, automation remains limited |
| Phase 17, advanced optional integrations and gap closures | materially usable | Suricata, optional Brevo webhook, optional SOGo, and SBOM assets |

## Final audit conclusion

The public repo no longer needs a vague parity statement. The exact remaining gaps are concentrated in:

- deeper automation for phases 15 and 16
- live production evidence and recovery material that must remain private
- site-specific control-plane behavior that cannot be generalized safely

For the current operator baseline, the public repo is coherent enough to serve as a public-safe implementation and operations reference.
