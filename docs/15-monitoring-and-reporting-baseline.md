# Monitoring and reporting baseline

## Purpose

This phase extends the public operations model with a monitoring and reporting
baseline suitable for the OpenBSD mail stack.

This phase focuses on:

- service status reporting
- operational summary generation
- lightweight health review
- operator-readable reports
- non-destructive monitoring guidance

## Why this matters

A resilient mail platform needs more than backups and restore drills. Operators
also need a simple way to answer:

- which services are expected to be up
- whether core ports are listening
- whether logs show obvious failures
- whether backup and restore guidance has been generated
- whether the system appears operationally healthy

This phase prepares the public project for that style of review without forcing
complex monitoring infrastructure.

## Public monitoring baseline

Recommended pattern:

- local-first checks
- report generation as text artifacts
- operator-triggered review
- conservative alerting model
- no self-healing automation by default

## Suggested checks

Examples of useful monitoring targets:

- `rcctl ls on`
- `rcctl check smtpd`
- `rcctl check dovecot`
- `rcctl check nginx`
- `rcctl check rspamd`
- `rcctl check redis`
- selected port listening checks
- recent log review targets
- recent backup artifact presence

## Reporting model

This phase generates:

- monitoring checklist guidance
- service review example
- daily report example
- monitoring summary artifact

The goal is to make it easy for operators to understand what to inspect and how
to summarize state.

## Next step

After this phase, the project is ready for optional public polish around
hardening reviews, compliance checks, or CI-style validation workflows.
