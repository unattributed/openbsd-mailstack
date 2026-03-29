#!/bin/ksh
# =============================================================================
# suricata/suricata_dump.ksh
# =============================================================================
# Summary:
#   suricata dump automation script.
#
# Usage:
#   suricata_dump.ksh --help
# =============================================================================
#
# Export Suricata summary + event data for the PF dashboard.
# Reads eve.json, produces suricata-summary.json and suricata-events.json,
# and writes them atomically into the dashboard directory.
#

set -euo pipefail

JQ=${JQ:-/usr/local/bin/jq}
SURICATA_BIN=${SURICATA_BIN:-/usr/local/bin/suricata}
EVE_LOG=${EVE_LOG:-/var/log/suricata/eve.json}
OUT_DIR=${OUT_DIR:-${SURICATA_DASHBOARD_ROOT:-/var/www/htdocs/pf}}
SUMMARY_NAME=${SUMMARY_NAME:-suricata-summary.json}
EVENTS_NAME=${EVENTS_NAME:-suricata-events.json}
TAIL_LINES=${TAIL_LINES:-2000}
EVENT_LIMIT=${EVENT_LIMIT:-200}
KEYWORDS=${KEYWORDS:-"ssh bruteforce tls smtp imap pop3 http certificate"}

# Summary:
#   usage helper.
usage() {
  cat <<'EOF' >&2
Usage: suricata_dump.ksh

Environment overrides:
  JQ=/path/to/jq
  SURICATA_BIN=/usr/local/bin/suricata
  EVE_LOG=/var/log/suricata/eve.json
  OUT_DIR=${SURICATA_DASHBOARD_ROOT:-/var/www/htdocs/pf}
  SUMMARY_NAME=suricata-summary.json
  EVENTS_NAME=suricata-events.json
  TAIL_LINES=2000
  EVENT_LIMIT=200
  KEYWORDS="ssh bruteforce tls ..."
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ ! -x "$JQ" ]; then
  echo "ERROR: jq not found at $JQ" >&2
  exit 1
fi

if [ ! -r "$EVE_LOG" ]; then
  echo "ERROR: cannot read Suricata log $EVE_LOG" >&2
  exit 1
fi

if [ ! -d "$OUT_DIR" ]; then
  echo "ERROR: output directory $OUT_DIR does not exist" >&2
  exit 1
fi

tmpdir="$(mktemp -d /tmp/suricata_dump.XXXXXX)"
trap 'rm -rf "$tmpdir"' INT TERM EXIT

tail -n "$TAIL_LINES" "$EVE_LOG" >"$tmpdir/eve-tail.json"

UPDATED_EPOCH="$(date +%s)"

if command -v rcctl >/dev/null 2>&1 && rcctl check suricata >/dev/null 2>&1; then
  STATUS="running"
else
  STATUS="stopped"
fi

if [ -x "$SURICATA_BIN" ]; then
  VERSION="$("$SURICATA_BIN" -V 2>/dev/null | awk '
    NR==1 {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^[0-9]+([.][0-9A-Za-z_-]+)+$/) {
          print $i
          exit
        }
      }
      print $NF
      exit
    }
  ')"
  [ -n "$VERSION" ] || VERSION="unknown"
else
  VERSION="unknown"
fi

LOG_DIR="$(dirname "$EVE_LOG")"
KEYWORDS_NORMALIZED="$(printf '%s' "$KEYWORDS" | tr '[:upper:]' '[:lower:]' | tr '\n' ' ')"

"$JQ" -s \
  --arg status "$STATUS" \
  --arg version "$VERSION" \
  --arg log_dir "$LOG_DIR" \
  --arg keywords "$KEYWORDS_NORMALIZED" \
  --argjson updated "$UPDATED_EPOCH" '
  def normalize:
    if . == null or . == "" then "unknown" else (tostring) end;
  def lower:
    if . == null then "" else (tostring | ascii_downcase) end;
  def event_epoch:
    (try (.timestamp | fromdateiso8601) catch null);
  def action_raw:
    (.verdict.action // .alert.action // .drop.action // .flow.action // .action // null);
  def action_text:
    (action_raw | lower);
  def signature_text:
    ((.alert.signature // .signature // "") | lower);
  def message_text:
    ((.alert.category // .message // "") | lower);
  def drop_alert_by_signature:
    (signature_text | test("(^|[^a-z])(drop|blocked|block( |-|_)listed|dshield block)([^a-z]|$)"));
  def drop_alert_by_message:
    (message_text | test("(^|[^a-z])(drop|block|reject|deny)([^a-z]|$)"));
  def is_enforced:
    (action_text | test("drop|block|reject|deny"));
  def looks_like_drop_alert:
    (drop_alert_by_signature or drop_alert_by_message);
  def action_bucket:
    if is_enforced then "blocked"
    else
      (action_text) as $a
      | if $a == "" then "other"
        elif ($a | test("allow|pass|accept")) then "allowed"
        elif ($a | test("alert")) then "alerted"
        else $a
        end
    end;
  def tally(f):
    reduce .[] as $item ({};
      ($item | f | normalize) as $key
      | .[$key] = ((.[$key] // 0) + 1)
    );
  def top_list(f; limit):
    (map({ key: (.|f | normalize), sample: . })
     | sort_by(.key)
     | group_by(.key)
     | map({ key: (.[0].key), count: length, sample: .[0].sample })
     | sort_by(.count) | reverse | .[0:limit]);
  def kw_list:
    ($keywords | ascii_downcase | split(" ") | map(select(length>0)));
  def keyword_hits:
    kw_list as $kw
    | [ $kw[] as $word |
        { keyword: $word,
          count: ( [ .[] |
            ( ((.alert.signature // "") + " " + (.alert.category // "") + " " + (.message // "")) | ascii_downcase )
            as $hay
            | select($hay | contains($word))
          ] | length )
        } ]
    | map(select(.count > 0));
  ([ .[] | select(.event_type == "alert") ]) as $alerts
  | ([ $alerts[] | select(is_enforced) ]) as $blocked
  | ([ $alerts[] | select(looks_like_drop_alert) ]) as $drop_alerts
  | (($blocked | map(event_epoch) | map(select(. != null)) | max) // null) as $last_blocked
  | {
    updated_epoch: $updated,
    suricata_version: $version,
    status: $status,
    log_dir: $log_dir,
    event_totals: (tally(.event_type // "unknown")),
    drops_last_24h: (
      [ $blocked[]?
             | (event_epoch) as $ts
             | select($ts != null and ($updated - $ts <= 86400)) ] | length),
    blocked_totals: ($blocked | length),
    drop_alert_totals: ($drop_alerts | length),
    top_blocked_signature: (
      ($blocked
       | map((.alert.signature // .signature // "unknown") | tostring)
       | sort
       | group_by(.)
       | map({ signature: .[0], count: length })
       | sort_by(.count) | reverse
       | .[0]) // null
    ),
    blocked_sources: (
      $blocked
      | map(.src_ip // .alert.src_ip // .flow.src_ip // "unknown")
      | map(normalize)
      | sort
      | group_by(.)
      | map({ ip: .[0], count: length })
      | sort_by(.count) | reverse | .[0:6]
    ),
    last_blocked_epoch: $last_blocked,
    last_blocked_ts: (if $last_blocked == null then null else ($last_blocked | todateiso8601) end),
    top_signatures: (
      ($alerts | top_list(.alert.signature // (.signature // "unknown"); 5))
      | map({ signature: .key, count: .count, severity: (.sample.alert.severity // null) })
    ),
    top_sources: (
      top_list(.src_ip // .alert.src_ip // .flow.src_ip // "unknown"; 5)
      | map({ ip: .key, count: .count })
    ),
    keyword_hits: ($alerts | keyword_hits),
    protocol_breakdown: (tally(.proto // .alert.proto // .flow.proto // "unknown")),
    action_breakdown: (tally(action_bucket))
  }
' "$tmpdir/eve-tail.json" >"$tmpdir/summary.json"

"$JQ" -s --argjson limit "$EVENT_LIMIT" '
  def lower:
    if . == null then "" else (tostring | ascii_downcase) end;
  def action_raw:
    (.verdict.action // .alert.action // .drop.action // .flow.action // .action // null);
  def action_text:
    (action_raw | lower);
  def is_enforced:
    (action_text | test("drop|block|reject|deny"));
  def action_bucket:
    if is_enforced then "blocked"
    else
      (action_text) as $a
      | if $a == "" then "other"
        elif ($a | test("allow|pass|accept")) then "allowed"
        elif ($a | test("alert")) then "alerted"
        else $a
        end
    end;
  map(select(.timestamp != null))
  | sort_by(.timestamp) | reverse
  | map({
      ts: .timestamp,
      event_type: .event_type,
      severity: (.alert.severity // null),
      action: (action_bucket),
      action_raw: (action_raw),
      blocked: (is_enforced),
      signature: (.alert.signature // .event_type // "event"),
      src_ip: (.src_ip // .alert.src_ip // .flow.src_ip // null),
      src_port: (.src_port // .alert.src_port // .flow.src_port // null),
      dest_ip: (.dest_ip // .alert.dest_ip // .flow.dest_ip // null),
      dest_port: (.dest_port // .alert.dest_port // .flow.dest_port // null),
      proto: (.proto // .alert.proto // .flow.proto // null),
      message: (.alert.category // .message // null)
    })
  | .[0:$limit]
' "$tmpdir/eve-tail.json" >"$tmpdir/events.json"

summary_tmp="$(mktemp "$OUT_DIR/.suricata-summary.XXXXXX")"
events_tmp="$(mktemp "$OUT_DIR/.suricata-events.XXXXXX")"

cp "$tmpdir/summary.json" "$summary_tmp"
cp "$tmpdir/events.json" "$events_tmp"
chmod 644 "$summary_tmp" "$events_tmp"

mv "$summary_tmp" "$OUT_DIR/$SUMMARY_NAME"
mv "$events_tmp" "$OUT_DIR/$EVENTS_NAME"
