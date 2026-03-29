# Authentication and Security Hardening Assets

This directory holds public-safe assets for Phase 15.

Included here:

- repo-safe doas policy templates
- repo-safe sshd hardening template
- public-safe authentication policy artifacts

Not included here:

- live `/etc/doas.conf`
- live `/etc/ssh/sshd_config`
- live operator names tied to a private deployment
- private MFA systems or identity backends

Use the tracked templates together with:

- `config/security.conf.example`
- `maint/doas-policy-baseline-check.ksh`
- `maint/doas-policy-transition.ksh`
- `maint/ssh-hardening-window.ksh`
- `maint/sshd-watchdog.ksh`
