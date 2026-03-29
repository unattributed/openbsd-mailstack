#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

LABEL=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --label)
      shift
      [ "$#" -gt 0 ] || { print -- "--label requires a value" >&2; exit 2; }
      LABEL="$1"
      ;;
    --)
      shift
      break
      ;;
    *)
      print -- "usage: $(basename "$0") --label label -- command [args...]" >&2
      exit 2
      ;;
  esac
  shift
done

[ -n "${LABEL}" ] || { print -- "label is required" >&2; exit 2; }
[ "$#" -gt 0 ] || { print -- "command is required" >&2; exit 2; }

JSON_ROOT="${CRON_JSON_ROOT:-/var/www/htdocs/pf}"
LOG_ROOT="${CRON_LOG_ROOT:-/var/log/openbsd-mailstack}"
MAIL_TO="${MAIL_TO:-}"
MAIL_SUBJECT_PREFIX="${MAIL_SUBJECT_PREFIX:-[openbsd-mailstack]}"
TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
SAFE_LABEL="$(print -- "${LABEL}" | tr '/ ' '__')"
TMP_OUT="$(mktemp /tmp/openbsd-mailstack-cron-report.XXXXXX)"
TMP_HTML="$(mktemp /tmp/openbsd-mailstack-cron-report-html.XXXXXX)"
trap 'rm -f "${TMP_OUT}" "${TMP_HTML}"' EXIT HUP INT TERM

ensure_dir() {
  [ -d "$1" ] || mkdir -p "$1"
}

ensure_dir "${JSON_ROOT}"
ensure_dir "${LOG_ROOT}"

if "$@" > "${TMP_OUT}" 2>&1; then
  STATUS="pass"
  EXIT_CODE=0
else
  STATUS="fail"
  EXIT_CODE=$?
fi

cp -f "${TMP_OUT}" "${LOG_ROOT}/${SAFE_LABEL}.latest.log"

{
  print -- '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>openbsd-mailstack cron report</title></head><body>'
  print -- "<h1>openbsd-mailstack cron report</h1>"
  print -- "<p>label=$(print -- "${LABEL}" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')</p>"
  print -- "<p>timestamp=${TS}</p>"
  print -- "<p>status=${STATUS}</p>"
  print -- '<pre>'
  sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "${TMP_OUT}"
  print -- '</pre></body></html>'
} > "${TMP_HTML}"

cat > "${JSON_ROOT}/cron-${SAFE_LABEL}.json" <<EOF
{
  "label": "${LABEL}",
  "timestamp": "${TS}",
  "status": "${STATUS}",
  "exit_code": "${EXIT_CODE}",
  "log_file": "${LOG_ROOT}/${SAFE_LABEL}.latest.log"
}
EOF

if [ -n "${MAIL_TO}" ] && command -v sendmail >/dev/null 2>&1; then
  {
    print -- "To: ${MAIL_TO}"
    print -- "Subject: ${MAIL_SUBJECT_PREFIX} ${LABEL} ${STATUS}"
    print -- "Content-Type: text/html; charset=utf-8"
    print -- ""
    cat "${TMP_HTML}"
  } | sendmail -t
fi

cat "${TMP_OUT}"
exit "${EXIT_CODE}"
