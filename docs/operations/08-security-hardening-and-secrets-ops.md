# Security Hardening and Secrets Operations

## Routine operator use

Use these helpers as part of the normal operating model:

### Monthly or after policy changes

- `./maint/doas-policy-baseline-check.ksh --check /etc/doas.conf`
- `doas ./maint/ssh-hardening-window.ksh --verify`

### Before major maintenance windows

- `./maint/doas-policy-transition.ksh --render`
- `doas ./maint/ssh-hardening-window.ksh --plan`
- `./maint/runtime-secret-layout.ksh --plan`

### After rotation or secret handling work

- `./maint/repo-secret-guard.ksh`
- `./maint/runtime-secret-layout.ksh --verify`

### Optional watchdog use

- `doas ./maint/sshd-watchdog.ksh --check-only --verbose`

## Design intent

These helpers are intentionally conservative.
They make the repo more automation-led for hardening and secret layout work,
while keeping real secrets, live operator identities, and private key material
outside git.
