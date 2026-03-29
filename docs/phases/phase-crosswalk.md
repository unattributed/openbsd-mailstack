# Phase Crosswalk

## Current public migration map

| Public phase | Current state | Notes |
|---|---|---|
| Phase 01, network and external access | materially usable | renders PF, WireGuard, Unbound, and DDNS assets |
| Phase 09, DNS and identity publishing | materially usable | aligned to shared DNS and DDNS inputs |
| Phase 11 to 13, backup and DR | materially usable | public-safe backup and DR workflows are present |
| Phase 14, monitoring | materially usable | baseline reporting and visibility helpers are present |
| Phase 15, security hardening and authentication | materially usable | now includes runnable `doas` and SSH hardening helpers plus rendered auth artifacts |
| Phase 16, secrets handling and key material management | materially usable | now includes host-local runtime secret layout tooling, rendered examples, and repo hygiene checks |

## Exact remaining gaps

The public repo no longer treats Phase 15 and 16 as documentation-only placeholders.

The remaining gaps are now intentional boundaries, not unimplemented core phases:

- live production evidence, recovery archives, and site-specific control-plane doctrine remain private
- provider-specific integrations beyond the published public-safe set are not generalized here
- operators still need to supply their own identities, secrets, private keys, and exposure policy
