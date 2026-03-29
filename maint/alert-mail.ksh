#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

TO="${MAIL_TO:-${1:-}}"
SUBJECT="${MAIL_SUBJECT:-${2:-openbsd-mailstack report}}"
BODY_FILE="${BODY_FILE:-}"

if [ -z "${TO}" ]; then
  print -- "usage: $(basename "$0") recipient@example.com [subject]" >&2
  exit 2
fi

if [ -n "${BODY_FILE}" ]; then
  [ -f "${BODY_FILE}" ] || { print -- "missing body file: ${BODY_FILE}" >&2; exit 1; }
  BODY_CONTENT="$(cat "${BODY_FILE}")"
else
  BODY_CONTENT="$(cat)"
fi

if command -v sendmail >/dev/null 2>&1; then
  {
    print -- "To: ${TO}"
    print -- "Subject: ${SUBJECT}"
    print -- "Content-Type: text/html; charset=utf-8"
    print -- ""
    print -- "${BODY_CONTENT}"
  } | sendmail -t
  print -- "sent mail to ${TO}"
else
  print -- "sendmail not available, report not sent" >&2
  exit 1
fi
