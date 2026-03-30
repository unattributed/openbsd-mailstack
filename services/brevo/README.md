# Brevo Webhook

This directory holds public-safe templates for an optional Brevo event webhook listener.

Included here:

- `brevo_webhook.py.template`, a threaded Python listener with serialized state updates
- `brevo_webhook.rcd.template`, an OpenBSD `rc.d` wrapper
- `brevo_webhook.locations.tmpl.template`, an nginx location include
- an example environment file

The public repo does not publish live webhook endpoints or live provider credentials.
