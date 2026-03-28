# Backup and disaster recovery

## Purpose

This phase defines a safe, repeatable backup and disaster recovery baseline
for the openbsd-mailstack project.

This is NOT destructive automation.

This phase provides:
- backup scope definition
- example backup scripts
- restore runbook
- operator guidance

## Backup scope

Critical data to protect:

- /etc
- /etc/ssl
- /etc/ssl/private
- /var/vmail
- MariaDB dumps
- /var/www
- repo configuration

## Backup model

- local-first
- tar + gzip
- operator-triggered
- no automatic deletion

## Restore model

Restore order:

1. base OS
2. packages
3. config (/etc)
4. TLS material
5. MariaDB
6. maildirs
7. services

## Verification

After restore:

- rcctl check smtpd
- rcctl check dovecot
- test IMAP login
- test mail send

