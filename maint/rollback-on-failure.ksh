#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

RUN_ID=""
STATE_DIR="${MAINTENANCE_STATE_DIR:-/var/db/openbsd-mailstack}"

usage() {
  cat <<'EOF2' >&2
usage: rollback-on-failure.ksh [--run-id ID]
EOF2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-id)
      shift
      [ "$#" -gt 0 ] || usage
      RUN_ID="$1"
      ;;
    --help|-h)
      usage
      ;;
    *)
      usage
      ;;
  esac
  shift
done

print -- "== rollback guidance =="
[ -n "${RUN_ID}" ] && print -- "run id: ${RUN_ID}"
print -- "1. inspect service status with: doas rcctl check postfix dovecot rspamd redis clamd freshclam nginx"
print -- "2. inspect package state with: pkg_info -q | sort"
print -- "3. inspect syspatch state with: syspatch -l and syspatch -c"
if [ -n "${RUN_ID}" ] && [ -d "${STATE_DIR}/runs/${RUN_ID}" ]; then
  print -- "4. compare against snapshot: ${STATE_DIR}/runs/${RUN_ID}"
fi
print -- "5. restore repo-managed configs from the last known good commit or backup set"
print -- "6. use the public backup and restore helpers if host config drift needs staged restoration"
print -- "7. re-run maint/regression-test.ksh after each corrective action"
