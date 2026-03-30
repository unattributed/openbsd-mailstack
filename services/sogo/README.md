# SOGo

This directory holds a public-safe optional SOGo baseline.

Included here:

- `sogo.conf.template`
- an nginx location include for proxying SOGo behind the mail vhost, using the control-plane wrapper template so `deny all;` remains active
- an example DB environment file

The public repo does not publish live SOGo database credentials or live domain names.
