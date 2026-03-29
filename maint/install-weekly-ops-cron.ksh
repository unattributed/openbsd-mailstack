#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

CRON_PATH="/var/cron/tabs/root"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --cron-path)
      shift
      [ "$#" -gt 0 ] || { print -- "--cron-path requires a value" >&2; exit 2; }
      CRON_PATH="$1"
      ;;
    *)
      print -- "usage: $0 [--cron-path PATH]" >&2
      exit 2
      ;;
  esac
  shift
done

TMP="$(mktemp /tmp/openbsd-mailstack-cron.XXXXXX)"
trap 'rm -f "${TMP}"' EXIT HUP INT TERM
if [ -f "${CRON_PATH}" ]; then
  cat "${CRON_PATH}" > "${TMP}"
fi
if ! grep -q 'weekly-maintenance-cron.ksh' "${TMP}" 2>/dev/null; then
  print -- '15 4 * * 0 /usr/local/sbin/weekly-maintenance-cron.ksh >> /var/log/openbsd-mailstack-maint.log 2>&1' >> "${TMP}"
fi
install -m 0600 "${TMP}" "${CRON_PATH}"
print -- "installed weekly maintenance cron in ${CRON_PATH}"
