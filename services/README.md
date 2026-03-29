# Services Tree

This directory holds tracked public-safe service assets and staged generated examples.

Tracked source assets live under service-specific directories such as:

- `mariadb/`
- `postfixadmin/`
- `postfix/`
- `dovecot/`
- `nginx/`
- `roundcube/`
- `rspamd/`
- `redis/`
- `clamd/`
- `freshclam/`
- `firewall/`
- `wireguard/`
- `dns/`
- `ddns/`
- `auth/`
- `secrets/`

Rendered public-safe examples live under `generated/rootfs/`.

Do not commit private keys, runtime dumps, `__pycache__`, or live local artifacts here.
