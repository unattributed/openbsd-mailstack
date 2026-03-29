#!/bin/ksh
# =============================================================================
# suricata/suricata_eve2pf.ksh
# =============================================================================
# Summary:
#   suricata eve2pf automation script.
#
# Usage:
#   suricata_eve2pf.ksh --help
# =============================================================================
#
# suricata_eve2pf.ksh
#
# Sync recent Suricata alerts from eve.json into a PF table.
# Default mode is "watch" (no blocking). Set MODE=block to enforce.
#

set -euo pipefail

EVE_LOG=${EVE_LOG:-/var/log/suricata/eve.json}
JQ=${JQ:-/usr/local/bin/jq}
PFCTL=${PFCTL:-/sbin/pfctl}

MODE=${MODE:-watch}              # watch | block
TABLE_WATCH=${TABLE_WATCH:-${SURICATA_PF_TABLE_WATCH:-suricata_watch}}
TABLE_BLOCK=${TABLE_BLOCK:-${SURICATA_PF_TABLE_BLOCK:-suricata_block}}
ALLOW_TABLE=${ALLOW_TABLE:-${SURICATA_PF_TABLE_ALLOW:-suricata_allow}}

TAIL_LINES=${TAIL_LINES:-8000}    # lines read from eve.json
LOOKBACK_SECONDS=${LOOKBACK_SECONDS:-1800}
MIN_HITS=${MIN_HITS:-3}          # legacy alias for ESCALATION_MIN_HITS

# Immediate block: high-confidence reputation families can be enforced after a
# single hit because trusted networks are allowlisted before PF blocks apply.
IMMEDIATE_BLOCK_SIG_RE=${IMMEDIATE_BLOCK_SIG_RE:-'^ET (DROP Dshield Block Listed Source|DROP Spamhaus DROP Listed Traffic Inbound|CINS Active Threat Intelligence Poor Reputation IP|COMPROMISED)'}
IMMEDIATE_MIN_HITS=${IMMEDIATE_MIN_HITS:-1}

# Escalation block: generic scans and exploit probes must hit an actually
# exposed public service to become block candidates.
SIG_PATTERN=${SIG_PATTERN:-'^ET (SCAN|DOS|EXPLOIT|COMPROMISED)'}
ESCALATION_SIG_RE=${ESCALATION_SIG_RE:-$SIG_PATTERN}
ESCALATION_MIN_HITS=${ESCALATION_MIN_HITS:-$MIN_HITS}
ESCALATION_PORTS=${ESCALATION_PORTS:-'22,25,80'}

# Signature IDs to ignore (local baseline + known noisy decoders).
IGNORE_SIG_IDS=${IGNORE_SIG_IDS:-'1000002,2200075,2231000,2260002,2047702,2054146,2054140,2063060,2054161,2047703,2054155,2063073'}

# Local nets that must never be blocked.
SAFE_NET_RE=${SAFE_NET_RE:-'^(10\\.44\\.|192\\.168\\.|127\\.|::1)'}

LOG=${LOG:-/var/log/suricata_eve2pf.log}
LOCKDIR=${LOCKDIR:-/var/run/suricata_eve2pf.lock}
DRY_RUN=${DRY_RUN:-0}

# Summary:
#   usage helper.
usage() {
  cat <<'USAGE' >&2
Usage: suricata_eve2pf.ksh

Env overrides:
  MODE=watch|block
  EVE_LOG=/var/log/suricata/eve.json
  TAIL_LINES=8000
  LOOKBACK_SECONDS=1800
  MIN_HITS=3
  IMMEDIATE_BLOCK_SIG_RE='^ET (DROP Dshield Block Listed Source|DROP Spamhaus DROP Listed Traffic Inbound|CINS Active Threat Intelligence Poor Reputation IP|COMPROMISED)'
  IMMEDIATE_MIN_HITS=1
  ESCALATION_SIG_RE='^ET (SCAN|DOS|EXPLOIT|COMPROMISED)'
  ESCALATION_MIN_HITS=3
  ESCALATION_PORTS='22,25,80'
  IGNORE_SIG_IDS='1000002,2200075,...'
  SAFE_NET_RE='^(10\.44\.|192\.168\.|127\.|::1)'
  TABLE_WATCH=${SURICATA_PF_TABLE_WATCH:-suricata_watch}
  TABLE_BLOCK=${SURICATA_PF_TABLE_BLOCK:-suricata_block}
  ALLOW_TABLE=${SURICATA_PF_TABLE_ALLOW:-suricata_allow}
  DRY_RUN=0
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

case "$MODE" in
  watch|block) ;;
  *) echo "ERROR: MODE must be watch or block" >&2; exit 1 ;;
esac

if [ ! -x "$JQ" ]; then
  echo "ERROR: jq not found at $JQ" >&2
  exit 1
fi

if [ ! -r "$EVE_LOG" ]; then
  echo "ERROR: cannot read $EVE_LOG" >&2
  exit 1
fi

if [ ! -x "$PFCTL" ]; then
  echo "ERROR: pfctl not found at $PFCTL" >&2
  exit 1
fi

if ! mkdir "$LOCKDIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCKDIR"' INT TERM EXIT

now_epoch=$(date +%s)
cutoff=$((now_epoch - LOOKBACK_SECONDS))
ports_re=$(printf '%s' "$ESCALATION_PORTS" | tr -d ' ' | sed 's/,/|/g')
[ -n "$ports_re" ] || ports_re='^$'
ports_re="^(${ports_re})$"

tmpdir=$(mktemp -d /tmp/suricata_eve2pf.XXXXXX)
trap 'rm -rf "$tmpdir"; rmdir "$LOCKDIR" 2>/dev/null || true' INT TERM EXIT

tail -n "$TAIL_LINES" "$EVE_LOG" | grep -a '"timestamp"' > "$tmpdir/eve-tail.json"

"$JQ" -r \
  --argjson cutoff "$cutoff" \
  --arg immediate_re "$IMMEDIATE_BLOCK_SIG_RE" \
  --arg escalation_re "$ESCALATION_SIG_RE" \
  --arg ports_re "$ports_re" \
  --arg ignore "$IGNORE_SIG_IDS" \
  --arg safe_re "$SAFE_NET_RE" '
  def ignore_list:
    ($ignore | split(",") | map(select(length > 0) | tonumber));
  def is_ignored($sid):
    (ignore_list | index($sid)) != null;
  # Parse timestamps like 2026-01-10T17:02:14.631234+0700 with strptime.
  def event_epoch:
    (try ((.timestamp // "" | tostring)
          | sub("\\.[0-9]+"; "")
          | strptime("%Y-%m-%dT%H:%M:%S%z")
          | mktime) catch 0);
  def sig_text:
    (.alert.signature // "" | tostring);
  def dest_port_text:
    ((.dest_port // .alert.dest_port // .flow.dest_port // "") | tostring);
  def match_class:
    if (sig_text | test($immediate_re)) then "immediate"
    elif ((sig_text | test($escalation_re)) and (dest_port_text | test($ports_re))) then "escalation"
    else empty end;
  select(.event_type == "alert")
  | select(event_epoch >= $cutoff)
  | select(.alert.severity <= 2)
  | select(is_ignored(.alert.signature_id // 0) | not)
  | (.src_ip // "" | tostring) as $ip
  | select($ip != "" and ($ip | test($safe_re) | not))
  | match_class as $class
  | select($class != "")
  | [$ip, $class] | @tsv
' "$tmpdir/eve-tail.json" \
  | sort \
  | uniq -c \
  | awk -v immediate="$IMMEDIATE_MIN_HITS" -v escalation="$ESCALATION_MIN_HITS" '
      {
        count[$2 " " $3] = $1
      }
      END {
        for (k in count) {
          split(k, parts, " ")
          ip = parts[1]
          klass = parts[2]
          min = (klass == "immediate") ? immediate : escalation
          if (count[k] >= min) {
            keep[ip] = 1
          }
        }
        for (ip in keep) {
          print ip
        }
      }
    ' \
  | sort -u \
  > "$tmpdir/candidates.txt"

final_list="$tmpdir/final.txt"
: > "$final_list"

if "$PFCTL" -t "$ALLOW_TABLE" -T show >/dev/null 2>&1; then
  allow_check=1
else
  allow_check=0
fi

while IFS= read -r ip; do
  [ -n "$ip" ] || continue
  if [ "$allow_check" -eq 1 ]; then
    if "$PFCTL" -t "$ALLOW_TABLE" -T test "$ip" >/dev/null 2>&1; then
      continue
    fi
  fi
  printf '%s\n' "$ip" >> "$final_list"
done < "$tmpdir/candidates.txt"

if [ "$MODE" = "block" ]; then
  table="$TABLE_BLOCK"
else
  table="$TABLE_WATCH"
fi

count=$(wc -l < "$final_list" | tr -d ' ')

if [ "$DRY_RUN" -ne 0 ]; then
  printf '%s mode=%s table=%s candidates=%s window=%ss\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$MODE" "$table" "$count" "$LOOKBACK_SECONDS" \
    >> "$LOG"
  exit 0
fi

if [ -s "$final_list" ]; then
  "$PFCTL" -t "$table" -T replace -f "$final_list" >/dev/null
else
  "$PFCTL" -t "$table" -T replace -f /dev/null >/dev/null
fi

printf '%s mode=%s table=%s candidates=%s window=%ss\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$MODE" "$table" "$count" "$LOOKBACK_SECONDS" \
  >> "$LOG"
