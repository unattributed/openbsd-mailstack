#!/bin/ksh
set -e
set -o pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
. "${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${PROJECT_ROOT}/scripts/lib/network-exposure.ksh"

load_network_exposure_config
validate_network_exposure_inputs

LOOKUP_CMD=""
if command -v drill >/dev/null 2>&1; then
  LOOKUP_CMD="drill"
elif command -v dig >/dev/null 2>&1; then
  LOOKUP_CMD="dig"
else
  die "drill or dig is required"
fi

for domain in ${DOMAINS}; do
  print -- "== ${domain} =="
  if [ "${LOOKUP_CMD}" = "drill" ]; then
    drill MX "${domain}" || true
    drill A "${MAIL_HOSTNAME}" || true
  else
    dig +short MX "${domain}" || true
    dig +short A "${MAIL_HOSTNAME}" || true
  fi
  print
done
