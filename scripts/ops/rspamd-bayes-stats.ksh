#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
MONITOR_LIB="${PROJECT_ROOT}/scripts/lib/monitoring-diagnostics.ksh"
. "${COMMON_LIB}"
. "${MONITOR_LIB}"

monitoring_load_config

RSPAMC_BIN="${RSPAMC_BIN:-/usr/local/bin/rspamc}"
RSPAMC_HOST="${RSPAMC_HOST:-${RSPAMD_CONTROLLER_BIND:-127.0.0.1:11334}}"
REDIS_CLI="${REDIS_CLI:-/usr/local/bin/redis-cli}"
BAYES_SPAM_MIN_LEARNS="${BAYES_SPAM_MIN_LEARNS:-50}"
BAYES_MAX_HAM_SPAM_RATIO="${BAYES_MAX_HAM_SPAM_RATIO:-20}"
BAYES_RATIO_MIN_SPAM_LEARNS="${BAYES_RATIO_MIN_SPAM_LEARNS:-50}"

[ -x "${RSPAMC_BIN}" ] || die "missing rspamc binary: ${RSPAMC_BIN}"

stats="$(${RSPAMC_BIN} -h "${RSPAMC_HOST}" stat 2>/dev/null || true)"
[ -n "${stats}" ] || die "unable to read rspamd stats from ${RSPAMC_HOST}"

ham="$(print -- "${stats}" | awk '/Statfile: BAYES_HAM/ { if (match($0,/learned: [0-9]+/)) { print substr($0, RSTART + 9, RLENGTH - 9); exit } }')"
spam="$(print -- "${stats}" | awk '/Statfile: BAYES_SPAM/ { if (match($0,/learned: [0-9]+/)) { print substr($0, RSTART + 9, RLENGTH - 9); exit } }')"
[ -n "${ham}" ] || ham=0
[ -n "${spam}" ] || spam=0

ratio="inf"
if [ "${spam}" -gt 0 ]; then
  ratio="$(awk -v h="${ham}" -v s="${spam}" 'BEGIN { printf "%.2f", h/s }')"
fi

print -- "rspamd bayes stats"
print -- "endpoint=${RSPAMC_HOST}"
print -- "ham=${ham}"
print -- "spam=${spam}"
print -- "ham_to_spam_ratio=${ratio}"

if [ -x "${REDIS_CLI}" ]; then
  _rham="$(${REDIS_CLI} HGET RS learns_ham 2>/dev/null || true)"
  _rspam="$(${REDIS_CLI} HGET RS learns_spam 2>/dev/null || true)"
  [ -n "${_rham}" ] || _rham="n/a"
  [ -n "${_rspam}" ] || _rspam="n/a"
  print -- "redis_learns_ham=${_rham}"
  print -- "redis_learns_spam=${_rspam}"
fi

if [ "${spam}" -lt "${BAYES_SPAM_MIN_LEARNS}" ]; then
  print -- "warn=BAYES_SPAM learns are low (${spam} < ${BAYES_SPAM_MIN_LEARNS})"
fi

if [ "${spam}" -ge "${BAYES_RATIO_MIN_SPAM_LEARNS}" ] && [ "${spam}" -gt 0 ]; then
  _imbalance="$(awk -v h="${ham}" -v s="${spam}" -v m="${BAYES_MAX_HAM_SPAM_RATIO}" 'BEGIN { if (h/s > m) print 1; else print 0 }')"
  if [ "${_imbalance}" -eq 1 ]; then
    print -- "warn=ham/spam learning ratio is high (> ${BAYES_MAX_HAM_SPAM_RATIO})"
  fi
fi
