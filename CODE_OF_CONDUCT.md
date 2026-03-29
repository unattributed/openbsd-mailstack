# Code of Conduct

## Purpose

`openbsd-mailstack` is a public, security-sensitive infrastructure project. The goal of this code of conduct is to keep project collaboration technically rigorous, respectful, and safe for operators, contributors, and reviewers.

## Expected Behavior

Contributors, maintainers, and participants are expected to:

- be respectful, even when disagreeing on design or implementation
- focus on facts, reproducibility, and operator safety
- keep review comments specific, actionable, and technically grounded
- assume good intent while still challenging unsafe or unclear changes
- keep discussion centered on the public repository scope
- protect sensitive information and respect the public and private project boundary

## Unacceptable Behavior

The following are not acceptable in project spaces:

- harassment, intimidation, or personal attacks
- insulting, demeaning, or hostile language
- publishing or requesting real secrets, credentials, recovery artifacts, or private incident evidence
- pressuring maintainers to expose private operational material that is intentionally out of scope
- deliberately unsafe advice that could put an operator deployment at risk
- spam, trolling, or repetitive bad-faith arguments

## Public and Private Boundary

This project intentionally separates reusable public automation from private operational state.

Participants must not post:

- private keys, API tokens, PATs, or passwords
- real production hostnames, addresses, or operator identities unless intentionally published and necessary
- encrypted or plaintext recovery archives
- private incident logs, telemetry, or customer data

If material is sensitive, move the discussion to the private channel described in `SECURITY.md`.

## Review Culture

Strong technical review is encouraged. That includes rejecting changes for security, reliability, or documentation quality reasons.

Do:

- explain what is wrong
- explain why it matters
- point to the relevant file, phase, or workflow
- propose a safer or clearer alternative where practical

Do not:

- make the review personal
- mock the contributor
- dismiss concerns without technical reasoning

## Reporting Conduct Issues

If you experience or observe behavior that violates this code of conduct, contact the project maintainer through the private security or maintainer contact path already described in `SECURITY.md`.

When reporting, include:

- what happened
- where it happened
- links or screenshots if appropriate
- any immediate safety or confidentiality concern

## Maintainer Response

Maintainers may take any action they consider appropriate to protect the project and its contributors, including:

- requesting a correction or apology
- editing, locking, or removing comments or discussions
- closing issues or pull requests
- restricting or banning participation

## Scope

This code of conduct applies to:

- issues
- pull requests
- discussions
- review comments
- project-linked communication spaces used for repository collaboration

## Project Values

This repository favors:

- operator safety
- reproducibility
- clarity
- kindness
- secure public defaults
- explicit boundaries between public automation and private operations
