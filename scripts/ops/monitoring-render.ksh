#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P 2>/dev/null || pwd -P)"
load_monitoring_inputs() {
  for _dir in     "${PROJECT_ROOT}/config"     "${PROJECT_ROOT}/config/local"     "/etc/openbsd-mailstack"     "/root/.config/openbsd-mailstack"     "${HOME:-/root}/.config/openbsd-mailstack"
  do
    [ -d "${_dir}" ] || continue
    for _f in "${_dir}"/*.conf; do
      [ -f "${_f}" ] || continue
      . "${_f}"
    done
  done
}
load_monitoring_inputs
MONITORING_PRIMARY_REPORT_EMAIL="${MONITORING_PRIMARY_REPORT_EMAIL:-$(printf '%s\n' "${MONITORING_REPORT_EMAIL:-ops@example.com}" | awk '{print $1}')}"
PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"
umask 022

DATA_ROOT="${DATA_ROOT:-${MONITORING_DATA_ROOT:-/var/www/monitor/data}}"
SNAP_DIR="${SNAP_DIR:-${DATA_ROOT}/snapshots}"
SITE_ROOT="${SITE_ROOT:-${MONITORING_SITE_ROOT:-/var/www/monitor/site}}"
SPARK_DIR="${SPARK_DIR:-${SITE_ROOT}/sparklines}"
TREND_DIR="${TREND_DIR:-${DATA_ROOT}/trends}"
MAIL_TREND_TSV="${MAIL_TREND_TSV:-${TREND_DIR}/mail_accepted_48h.tsv}"
MAIL_CONNECT_TREND_TSV="${MAIL_CONNECT_TREND_TSV:-${TREND_DIR}/mail_connect_48h.tsv}"
MAIL_REJECT_TREND_TSV="${MAIL_REJECT_TREND_TSV:-${TREND_DIR}/mail_rejected_48h.tsv}"
MAIL_NONCOMPLIANT_METHODS_TSV="${MAIL_NONCOMPLIANT_METHODS_TSV:-${TREND_DIR}/mail_noncompliant_methods_24h.tsv}"
MAIL_CONNECTION_CATALOG_TSV="${MAIL_CONNECTION_CATALOG_TSV:-${TREND_DIR}/mail_connection_catalog.tsv}"
MAIL_CONNECTION_SOURCES_TSV="${MAIL_CONNECTION_SOURCES_TSV:-${TREND_DIR}/mail_connection_sources.tsv}"
SURICATA_TREND_TSV="${SURICATA_TREND_TSV:-${TREND_DIR}/suricata_alerts_48h.tsv}"
PFSTAT_BASE_URL="${PFSTAT_BASE_URL:-/pfstat}"
AGENT_DATA_DIR="${AGENT_DATA_DIR:-${DATA_ROOT}/agent}"
AGENT_SUMMARY_FILE="${AGENT_SUMMARY_FILE:-${AGENT_DATA_DIR}/summary.kv}"
AGENT_QUEUE_TSV="${AGENT_QUEUE_TSV:-${AGENT_DATA_DIR}/open-ticket-queue.tsv}"
AGENT_QUEUE_JSON="${AGENT_QUEUE_JSON:-${AGENT_DATA_DIR}/open-ticket-queue.json}"
AGENT_EMERGENCY_TSV="${AGENT_EMERGENCY_TSV:-${AGENT_DATA_DIR}/emergency-queue.tsv}"
AGENT_EMERGENCY_JSON="${AGENT_EMERGENCY_JSON:-${AGENT_DATA_DIR}/emergency-queue.json}"
AGENT_REFUSAL_TSV="${AGENT_REFUSAL_TSV:-${AGENT_DATA_DIR}/input-refusals.tsv}"
AGENT_SUMMARY_JSON="${AGENT_SUMMARY_JSON:-${AGENT_DATA_DIR}/summary.json}"
AGENT_POLICY_TRUST_KV="${AGENT_POLICY_TRUST_KV:-${AGENT_DATA_DIR}/policy-trust.kv}"
AGENT_POLICY_TRUST_JSON="${AGENT_POLICY_TRUST_JSON:-${AGENT_DATA_DIR}/policy-trust.json}"
AGENT_LAST_REPORT_TXT="${AGENT_LAST_REPORT_TXT:-${AGENT_DATA_DIR}/latest-report.txt}"
AGENT_STATE_DIR="${AGENT_STATE_DIR:-/var/db/openbsd-self-hosting/ops-agent}"
AGENT_ACTION_LOG="${AGENT_ACTION_LOG:-${AGENT_STATE_DIR}/action-log.tsv}"
AGENT_POLICY_FILE="${AGENT_POLICY_FILE:-/etc/ops-agent/policy.conf}"

mkdir -p "${SITE_ROOT}" "${SPARK_DIR}"

latest="$(ls -1 "${SNAP_DIR}"/*.kv 2>/dev/null | sort | tail -n 1 || true)"
[ -n "${latest}" ] || {
  printf 'render failed: no snapshots in %s\n' "${SNAP_DIR}" >&2
  exit 1
}

prev="$(ls -1 "${SNAP_DIR}"/*.kv 2>/dev/null | sort | tail -n 2 | head -n 1 || true)"

# Summary:
#   kv_get helper.
kv_get() {
  f="$1"
  key="$2"
  def="${3:-}"
  [ -r "${f}" ] || { printf '%s\n' "${def}"; return 0; }
  v="$(awk -F= -v k="${key}" '$1==k {sub(/^[^=]*=/, "", $0); print; exit}' "${f}" 2>/dev/null || true)"
  [ -n "${v}" ] && printf '%s\n' "${v}" || printf '%s\n' "${def}"
}

# Summary:
#   to_int helper.
to_int() {
  v="$1"
  case "${v}" in
    ''|*[!0-9-]*) printf '0\n' ;;
    *) printf '%s\n' "${v}" ;;
  esac
}

# Summary:
#   delta_int helper.
delta_int() {
  n1="$(to_int "$1")"
  n2="$(to_int "$2")"
  printf '%s\n' "$((n1 - n2))"
}

# Summary:
#   atomic_install helper.
atomic_install() {
  mode="$1"
  src="$2"
  dest="$3"
  tmp="$(mktemp "${dest}.tmp.XXXXXX")"
  install -m "${mode}" "${src}" "${tmp}"
  mv -f "${tmp}" "${dest}"
}

# Summary:
#   atomic_write_stdin helper.
atomic_write_stdin() {
  dest="$1"
  mode="${2:-0644}"
  tmp="$(mktemp "${dest}.tmp.XXXXXX")"
  cat > "${tmp}"
  chmod "${mode}" "${tmp}"
  mv -f "${tmp}" "${dest}"
}

# Summary:
#   html_escape helper.
html_escape() {
  printf '%s' "$*" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"
}

# Summary:
#   list_items_from_delim helper for pipe-delimited snapshot fields.
list_items_from_delim() {
  raw="$1"
  mode="$2"
  empty="${3:-none}"

  norm="$(printf '%s' "${raw}" | tr '\r\n' ' ' | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')"
  case "${norm}" in
    ''|none|None|NONE)
      printf '<li>%s</li>' "$(html_escape "${empty}")"
      return 0
      ;;
  esac

  if [ "${mode}" = "double" ]; then
    split="$(printf '%s' "${norm}" | sed 's/[[:space:]]*||[[:space:]]*/\
/g')"
  else
    split="$(printf '%s' "${norm}" | sed 's/[[:space:]]*|[[:space:]]*/\
/g')"
  fi

  items=""
  while IFS= read -r line; do
    clean="$(printf '%s' "${line}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "${clean}" ] || continue
    items="${items}<li>$(html_escape "${clean}")</li>"
  done <<EOF_ITEMS
${split}
EOF_ITEMS

  [ -n "${items}" ] || items="<li>$(html_escape "${empty}")</li>"
  printf '%s' "${items}"
}

# Summary:
#   build backup job rows directly from the active root crontab.
build_backup_job_rows() {
  _cron_lines="$(crontab -l 2>/dev/null || true)"
  if [ -z "${_cron_lines}" ]; then
    printf '<tr><td colspan="3">no backup jobs were detected in the active root crontab</td></tr>\n'
    return 0
  fi

  printf '%s\n' "${_cron_lines}" | awk '
    function esc(s) {
      gsub(/&/, "\\&amp;", s)
      gsub(/</, "\\&lt;", s)
      gsub(/>/, "\\&gt;", s)
      gsub(/"/, "\\&quot;", s)
      gsub(/\047/, "\\&#39;", s)
      return s
    }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    NF < 6 { next }
    {
      schedule = $1 " " $2 " " $3 " " $4 " " $5
      cmd = ""
      for (i = 6; i <= NF; i++) {
        cmd = cmd (i == 6 ? "" : " ") $i
      }

      job = ""
      if (cmd ~ /\/usr\/local\/sbin\/nightly-dr-snapshot\.ksh/) job = "nightly DR snapshot"
      else if (cmd ~ /\/usr\/local\/sbin\/phase10-backup-mysql-cron\.sh/) job = "phase10 mysql backup"
      else if (cmd ~ /\/usr\/local\/sbin\/phase10-bakconf/) job = "phase10 configuration backup"
      else if (cmd ~ /\/usr\/local\/sbin\/phase10-backup-mailstack/) job = "phase10 mailstack backup"
      else next

      printf "<tr><td>%s</td><td class=\"mono\">%s</td><td class=\"mono\">%s</td></tr>\n", esc(job), esc(schedule), esc(cmd)
      rows++
    }
    END {
      if (rows == 0) {
        printf "<tr><td colspan=\"3\">no backup jobs were detected in the active root crontab</td></tr>\n"
      }
    }
  '
}

# Summary:
#   build rows for interfaces with failure counters or collisions.
build_network_interface_issue_rows() {
  _netstat_snapshot="$(netstat -in 2>/dev/null || true)"
  if [ -z "${_netstat_snapshot}" ]; then
    printf '<tr><td colspan="5">netstat interface data was unavailable for this render</td></tr>\n'
    return 0
  fi

  printf '%s\n' "${_netstat_snapshot}" | awk '
    function esc(s) {
      gsub(/&/, "\\&amp;", s)
      gsub(/</, "\\&lt;", s)
      gsub(/>/, "\\&gt;", s)
      gsub(/"/, "\\&quot;", s)
      gsub(/\047/, "\\&#39;", s)
      return s
    }
    NR == 1 { next }
    NF < 9 { next }
    {
      ifail = $6 + 0
      ofail = $8 + 0
      colls = $9 + 0
      if (ifail <= 0 && ofail <= 0 && colls <= 0) next

      note = ""
      if (ifail > 0) note = "input failures=" ifail
      if (ofail > 0) note = note (note != "" ? "; " : "") "output failures=" ofail
      if (colls > 0) note = note (note != "" ? "; " : "") "collisions=" colls
      if (note == "") note = "inspect interface counters"

      printf "<tr><td class=\"mono\">%s</td><td class=\"mono\">%s</td><td class=\"mono\">%s</td><td>%d / %d / %d</td><td>%s</td></tr>\n", esc($1), esc($3), esc($4), ifail, ofail, colls, esc(note)
      rows++
    }
    END {
      if (rows == 0) {
        printf "<tr><td colspan=\"5\">no interface failure counters or collisions were present in the current netstat snapshot</td></tr>\n"
      }
    }
  '
}

# Summary:
#   build rows for recent network-device issues seen in syslog.
build_network_log_issue_rows() {
  if [ ! -r /var/log/messages ]; then
    printf '<tr><td colspan="4">/var/log/messages is not readable for network-device issue scanning</td></tr>\n'
    return 0
  fi

  _log_tail="$(tail -n 4000 /var/log/messages 2>/dev/null || true)"
  if [ -z "${_log_tail}" ]; then
    printf '<tr><td colspan="4">no recent entries were available in /var/log/messages for network-device issue scanning</td></tr>\n'
    return 0
  fi

  printf '%s\n' "${_log_tail}" | awk '
    function esc(s) {
      gsub(/&/, "\\&amp;", s)
      gsub(/</, "\\&lt;", s)
      gsub(/>/, "\\&gt;", s)
      gsub(/"/, "\\&quot;", s)
      gsub(/\047/, "\\&#39;", s)
      return s
    }
    /arp info overwritten for [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ by / {
      ts = $1 " " $2 " " $3
      ip = $10
      mac = $12
      iface = $14
      key = "arp|" iface "|" ip
      arp_count[key]++
      arp_last[key] = ts
      arp_iface[key] = iface
      arp_ip[key] = ip
      if (arp_macs[key] == "") arp_macs[key] = mac
      else if (("," arp_macs[key] ",") !~ ("," mac ",")) arp_macs[key] = arp_macs[key] "," mac
      next
    }
    {
      ts = $1 " " $2 " " $3
      lower = tolower($0)
      if (lower ~ /(link down|no carrier|watchdog timeout|timed out|media mismatch|duplex mismatch|carrier lost|input error|output error|link state)/) {
        generic_count[$0]++
        generic_last[$0] = ts
      }
    }
    END {
      rows = 0
      for (k in arp_count) {
        printf "<tr><td>arp ownership churn</td><td>%d</td><td class=\"mono\">%s</td><td class=\"mono\">iface=%s ip=%s macs=%s</td></tr>\n", arp_count[k], esc(arp_last[k]), esc(arp_iface[k]), esc(arp_ip[k]), esc(arp_macs[k])
        rows++
      }
      for (line in generic_count) {
        printf "<tr><td>device log warning</td><td>%d</td><td class=\"mono\">%s</td><td class=\"mono\">%s</td></tr>\n", generic_count[line], esc(generic_last[line]), esc(line)
        rows++
      }
      if (rows == 0) {
        printf "<tr><td colspan=\"4\">no recent network-device log issues matched the current heuristics</td></tr>\n"
      }
    }
  '
}

# Summary:
#   mail_noncompliant_method_description helper for operator-friendly meanings.
mail_noncompliant_method_description() {
  _m="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
  case "${_m}" in
    NO_METHOD)
      printf '%s\n' "No non-compliant method observed in the current catalog window."
      ;;
    BARE_NEWLINE)
      printf '%s\n' "Client sent LF-only line endings (missing CRLF), violating SMTP framing rules."
      ;;
    COMMAND_TIMEOUT|*TIMEOUT*)
      printf '%s\n' "Client stalled or failed to complete a command inside the postscreen time limit."
      ;;
    PREGREET|*PREGREET*)
      printf '%s\n' "Client sent data before the server greeting (pregreet behavior)."
      ;;
    HELO|EHLO|MAIL|RCPT|DATA|RSET|VRFY|EXPN|NOOP|QUIT|STARTTLS|AUTH)
      printf '%s\n' "SMTP verb arrived in a non-compliant phase and was rejected by protocol checks."
      ;;
    OTHER|UNKNOWN)
      printf '%s\n' "Unclassified non-compliant payload token extracted from maillog."
      ;;
    [0-9]*)
      printf '%s\n' "Numeric token extracted from malformed/non-SMTP payload observed in maillog."
      ;;
    *)
      printf '%s\n' "Raw token extracted from rejected/non-compliant command payload in maillog history."
      ;;
  esac
}

# Summary:
#   build_mail_noncompliant_method_rows helper for methods table rows.
build_mail_noncompliant_method_rows() {
  _f="$1"
  _rows=""
  [ -r "${_f}" ] || {
    printf '<tr><td class="mono">NO_METHOD</td><td>0</td><td>No non-compliant method observed in the current catalog window.</td></tr>'
    return 0
  }

  while IFS="$(printf '\t')" read -r _method _count _rest; do
    [ -n "${_method}" ] || continue
    _method_h="$(html_escape "${_method}")"
    _count_i="$(to_int "${_count}")"
    _desc_h="$(html_escape "$(mail_noncompliant_method_description "${_method}")")"
    _rows="${_rows}<tr><td class=\"mono\">${_method_h}</td><td>${_count_i}</td><td>${_desc_h}</td></tr>"
  done < "${_f}"

  [ -n "${_rows}" ] || _rows='<tr><td class="mono">NO_METHOD</td><td>0</td><td>No non-compliant method observed in the current catalog window.</td></tr>'
  printf '%s' "${_rows}"
}

# Summary:
#   build_topn_rows_from_tsv helper for readable table mirrors of sparkline data.
build_topn_rows_from_tsv() {
  _f="$1"
  _max="$2"
  _empty_label="${3:-none}"
  _empty_h="$(html_escape "${_empty_label}")"
  _rows=""
  _idx=0

  [ -r "${_f}" ] || {
    printf '<tr><td class="mono">%s</td><td>0</td></tr>' "${_empty_h}"
    return 0
  }

  while IFS="$(printf '\t')" read -r _label _count _rest; do
    [ -n "${_label}" ] || continue
    _idx=$((_idx + 1))
    [ "${_idx}" -le "${_max}" ] || break
    _label_h="$(html_escape "${_label}")"
    _count_i="$(to_int "${_count}")"
    _rows="${_rows}<tr><td class=\"mono\">${_label_h}</td><td>${_count_i}</td></tr>"
  done < "${_f}"

  [ -n "${_rows}" ] || _rows="<tr><td class=\"mono\">${_empty_h}</td><td>0</td></tr>"
  printf '%s' "${_rows}"
}

# Summary:
#   status_chip helper.
status_chip() {
  s="$1"
  case "${s}" in
    ok|OK|pass|PASS|healthy|HEALTHY)
      printf '<span class="chip chip-ok">%s</span>' "$(html_escape "${s}")"
      ;;
    warn|WARN|degraded|DEGRADED)
      printf '<span class="chip chip-warn">%s</span>' "$(html_escape "${s}")"
      ;;
    fail|FAIL|critical|CRITICAL)
      printf '<span class="chip chip-bad">%s</span>' "$(html_escape "${s}")"
      ;;
    *)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
  esac
}

# Summary:
#   policy_get helper for key=value files with comments.
policy_get() {
  _f="$1"
  _k="$2"
  _d="${3:-}"
  [ -r "${_f}" ] || { printf '%s\n' "${_d}"; return 0; }
  _v="$(awk -F= -v k="${_k}" '
    /^[[:space:]]*#/ {next}
    /^[[:space:]]*$/ {next}
    {
      key=$1
      sub(/^[[:space:]]+/, "", key)
      sub(/[[:space:]]+$/, "", key)
      val=substr($0, index($0, "=") + 1)
      sub(/^[[:space:]]+/, "", val)
      sub(/[[:space:]]+$/, "", val)
      if (key == k) {
        print val
        exit
      }
    }
  ' "${_f}" 2>/dev/null || true)"
  [ -n "${_v}" ] && printf '%s\n' "${_v}" || printf '%s\n' "${_d}"
}

# Summary:
#   action_state_chip helper for phase-14 action states.
action_state_chip() {
  s="$1"
  case "${s}" in
    executed_ok)
      printf '<span class="chip chip-ok">%s</span>' "$(html_escape "${s}")"
      ;;
    executed_fail)
      printf '<span class="chip chip-bad">%s</span>' "$(html_escape "${s}")"
      ;;
    requires_human_approval|policy_integrity_review_required|upstream_trust_review_required)
      printf '<span class="chip chip-bad">%s</span>' "$(html_escape "${s}")"
      ;;
    deferred_cooldown|deferred_max_per_run|assist_review_required|manual_review_required|replay_suppressed)
      printf '<span class="chip chip-warn">%s</span>' "$(html_escape "${s}")"
      ;;
    *)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
  esac
}

# Summary:
#   policy_mode_chip helper for phase-14 policy gates.
policy_mode_chip() {
  s="$1"
  case "${s}" in
    auto_safe)
      printf '<span class="chip chip-ok">%s</span>' "$(html_escape "${s}")"
      ;;
    assist)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
    manual)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
    *)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
  esac
}

# Summary:
#   trust_state_chip helper for source/policy trust states.
trust_state_chip() {
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "${s}" in
    repo_baseline|approved_override|verified|ok)
      printf '<span class="chip chip-ok">%s</span>' "$(html_escape "${s}")"
      ;;
    degraded|approval_missing)
      printf '<span class="chip chip-warn">%s</span>' "$(html_escape "${s}")"
      ;;
    fail_closed|tampered|downgraded|invalid)
      printf '<span class="chip chip-bad">%s</span>' "$(html_escape "${s}")"
      ;;
    *)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
  esac
}

# Summary:
#   risk_level_chip helper for deterministic queue priority levels.
risk_level_chip() {
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "${s}" in
    critical|high)
      printf '<span class="chip chip-bad">%s</span>' "$(html_escape "${s}")"
      ;;
    medium)
      printf '<span class="chip chip-warn">%s</span>' "$(html_escape "${s}")"
      ;;
    low)
      printf '<span class="chip chip-ok">%s</span>' "$(html_escape "${s}")"
      ;;
    *)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
  esac
}

# Summary:
#   emergency_state_chip helper for emergency handling states.
emergency_state_chip() {
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "${s}" in
    breakglass_review)
      printf '<span class="chip chip-bad">%s</span>' "$(html_escape "${s}")"
      ;;
    urgent_human)
      printf '<span class="chip chip-warn">%s</span>' "$(html_escape "${s}")"
      ;;
    none)
      printf '<span class="chip chip-ok">%s</span>' "$(html_escape "${s}")"
      ;;
    *)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
  esac
}

# Summary:
#   approval_gate_chip helper for operator approval states.
approval_gate_chip() {
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "${s}" in
    none)
      printf '<span class="chip chip-ok">%s</span>' "$(html_escape "${s}")"
      ;;
    operator_review)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
    human_approval_required|policy_integrity_hold|upstream_trust_hold)
      printf '<span class="chip chip-bad">%s</span>' "$(html_escape "${s}")"
      ;;
    *)
      printf '<span class="chip chip-warn">%s</span>' "$(html_escape "${s}")"
      ;;
  esac
}

# Summary:
#   agent_run_mode_chip helper for --run/--analyze/--report semantics.
agent_run_mode_chip() {
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "${s}" in
    run)
      printf '<span class="chip chip-ok">%s</span>' "$(html_escape "${s}")"
      ;;
    analyze|report)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
    *)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
  esac
}

# Summary:
#   emit_ticket_event helper.
emit_ticket_event() {
  typeset _evt_epoch _evt_created_iso _evt_ticket_id _evt_type _evt_severity _evt_state _evt_summary _evt_evidence _evt_action
  _evt_epoch="$1"
  _evt_created_iso="$2"
  _evt_ticket_id="$3"
  _evt_type="$4"
  _evt_severity="$5"
  _evt_state="$6"
  _evt_summary="$7"
  _evt_evidence="$8"
  _evt_action="$9"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${_evt_epoch}" "${_evt_created_iso}" "${_evt_ticket_id}" "${_evt_type}" "${_evt_severity}" "${_evt_state}" "${_evt_summary}" "${_evt_evidence}" "${_evt_action}" >> "${ticket_event_tmp}"
}

# Summary:
#   choose probe address for tcp listener checks, preferring wg/non-loopback.
pick_probe_ip_for_port() {
  _port="$1"
  _picked="$(netstat -an -f inet -p tcp 2>/dev/null | awk -v want="${_port}" '
    BEGIN { first_non_loop=""; wg=""; loop="" }
    $1 ~ /^tcp/ && toupper($0) ~ /LISTEN/ {
      addr=$4
      n=split(addr, a, ".")
      if (n < 2) next
      port=a[n]
      if (port != want) next
      ip=substr(addr, 1, length(addr)-length(port)-1)
      if (ip=="*" || ip=="0.0.0.0") next
      if (ip ~ /^10\.44\./) { wg=ip; next }
      if (ip=="127.0.0.1") { if (loop=="") loop=ip; next }
      if (first_non_loop=="") first_non_loop=ip
    }
    END {
      if (wg!="") print wg
      else if (first_non_loop!="") print first_non_loop
      else if (loop!="") print loop
    }
  ')"
  [ -n "${_picked}" ] || _picked="127.0.0.1"
  printf '%s\n' "${_picked}"
}

# Summary:
#   classify URL probe states for web endpoint inventory.
web_url_status_chip() {
  s="$1"
  case "${s}" in
    up)
      printf '<span class="chip chip-ok">%s</span>' "$(html_escape "${s}")"
      ;;
    policy_enforced)
      printf '<span class="chip chip-ok">%s</span>' "$(html_escape "${s}")"
      ;;
    missing)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
    restricted)
      printf '<span class="chip chip-warn">%s</span>' "$(html_escape "${s}")"
      ;;
    down)
      printf '<span class="chip chip-bad">%s</span>' "$(html_escape "${s}")"
      ;;
    *)
      printf '<span class="chip chip-neutral">%s</span>' "$(html_escape "${s}")"
      ;;
  esac
}

# Summary:
#   classify expected access model for a monitored URL path.
web_url_expected_policy() {
  p="$1"
  case "${p}" in
    /|/mail|/mail/|/mail/*|/sogo|/sogo/|/sogo/*|/postfixadmin|/postfixadmin/|/postfixadmin/*|/rspamd|/rspamd/|/rspamd/*|/_ops/monitor|/_ops/monitor/|/_ops/monitor/*.html)
      printf 'protected\n'
      ;;
    /_ops/monitor/data/|/_ops/monitor/data/*|/rspamd/|/rspamd/*|/postfixadmin/setup.php|/postfixadmin/upgrade.php|/pfstat|/pfstat/|/SOGo.woa/WebServerResources/|/SOGo/WebServerResources/|/.well-known/caldav|/.well-known/carddav|/principals/)
      printf 'protected\n'
      ;;
    /brevo/webhook)
      printf 'webhook\n'
      ;;
    /favicon.ico|/robots.txt)
      printf 'optional\n'
      ;;
    *)
      printf 'public\n'
      ;;
  esac
}

# Summary:
#   map URL path to the owning web service.
web_service_label() {
  p="$1"
  case "${p}" in
    /mail|/mail/|/mail/*)
      printf 'roundcube webmail (wg-clients only)\n'
      ;;
    /postfixadmin|/postfixadmin/|/postfixadmin/*)
      printf 'postfixadmin (wg-clients only)\n'
      ;;
    /sogo|/sogo/|/sogo/*|/SOGo|/SOGo/*|/.well-known/caldav|/.well-known/carddav|/principals/)
      printf 'sogo groupware (wg-clients only)\n'
      ;;
    /pf|/pf/|/pf/*|/pfstat|/pfstat/|/pfstat.html|/suricata.html)
      printf 'pf dashboard\n'
      ;;
    /_ops/monitor|/_ops/monitor/|/_ops/monitor/*)
      printf 'ops monitor (wg-clients only)\n'
      ;;
    /rspamd|/rspamd/|/rspamd/*)
      printf 'rspamd ui (wg-clients only)\n'
      ;;
    /brevo/webhook)
      printf 'brevo webhook relay\n'
      ;;
    /stub_status)
      printf 'nginx stub status\n'
      ;;
    /.well-known/acme-challenge/*|/.well-known/acme-challenge/)
      printf 'acme challenge responder\n'
      ;;
    /)
      printf 'roundcube entrypoint redirect (wg-clients only)\n'
      ;;
    *)
      printf 'nginx endpoint\n'
      ;;
  esac
}

# Summary:
#   new_ticket_id helper for persistent incident ids.
new_ticket_id() {
  typeset _id_key _id_epoch _id_hash _id_slug
  _id_key="$1"
  _id_epoch="$2"
  _id_hash="$(printf '%s' "${_id_key}-${_id_epoch}" | cksum | awk '{print $1}')"
  _id_slug="$(printf '%s' "${_id_key}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')"
  _id_slug="$(printf '%s' "${_id_slug}" | sed 's/^-*//; s/-*$//')"
  printf 'inc-%s-%s\n' "${_id_slug}" "${_id_hash}"
}

# Summary:
#   make_empty_trend_svg helper.
make_empty_trend_svg() {
  out="$1"
  label="$2"
  atomic_write_stdin "${out}" 0644 <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="980" height="260" viewBox="0 0 980 260" role="img" aria-label="${label}">
  <rect x="0" y="0" width="980" height="260" fill="#0a1220" rx="14"/>
  <text x="30" y="42" fill="#95a7bc" font-size="20">${label}</text>
  <text x="30" y="86" fill="#6f8298" font-size="14">no trend data available</text>
</svg>
SVG
}

# Summary:
#   make_tsv_trend_svg helper.
make_tsv_trend_svg() {
  in="$1"
  out="$2"
  title="$3"
  stroke="$4"
  tmp="$(mktemp "${out}.tmp.XXXXXX")"

  [ -s "${in}" ] || {
    make_empty_trend_svg "${out}" "${title}"
    rm -f "${tmp}"
    return 0
  }

  awk -F'\t' -v title="${title}" -v stroke="${stroke}" '
    function esc(s) {
      gsub(/&/, "\\&amp;", s)
      gsub(/</, "\\&lt;", s)
      gsub(/>/, "\\&gt;", s)
      return s
    }
    {
      n++
      epoch[n] = $1 + 0
      label[n] = $2
      val[n] = $3 + 0
      sum += val[n]
      if (n == 1 || val[n] > max) max = val[n]
    }
    END {
      w = 980
      h = 260
      left = 58
      right = w - 24
      stats_y = 30
      top = 46
      bottom = h - 52
      pw = right - left
      ph = bottom - top

      if (n < 1) {
        print "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"980\" height=\"260\" viewBox=\"0 0 980 260\"><rect x=\"0\" y=\"0\" width=\"980\" height=\"260\" fill=\"#0a1220\" rx=\"14\"/><text x=\"30\" y=\"42\" fill=\"#95a7bc\" font-size=\"20\">" esc(title) "</text><text x=\"30\" y=\"86\" fill=\"#6f8298\" font-size=\"14\">no trend data available</text></svg>"
        exit
      }
      if (max < 1) max = 1

      print "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"980\" height=\"260\" viewBox=\"0 0 980 260\" role=\"img\" aria-label=\"" esc(title) "\">"
      print "  <rect x=\"0\" y=\"0\" width=\"980\" height=\"260\" fill=\"#071223\" rx=\"14\"/>"

      for (g = 0; g <= 4; g++) {
        y = bottom - (g * (ph / 4.0))
        gv = int((g * max / 4.0) + 0.5)
        printf "  <line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" stroke=\"#203248\" stroke-width=\"1\"/>\n", left, y, right, y
        printf "  <text x=\"%d\" y=\"%.2f\" fill=\"#89a0b8\" font-size=\"12\" text-anchor=\"end\">%d</text>\n", left - 10, y + 4, gv
      }

      for (i = 1; i <= n; i++) {
        if (n == 1) {
          x = left
        } else {
          x = left + ((i - 1) * pw / (n - 1))
        }
        y = bottom - ((val[i] / max) * ph)
        points = points sprintf("%s%.2f,%.2f", (i == 1 ? "" : " "), x, y)
        area = area sprintf("%s%.2f,%.2f", (i == 1 ? "" : " "), x, y)
      }

      area = sprintf("%.2f,%.2f %s %.2f,%.2f", left, bottom, area, right, bottom)
      printf "  <polygon points=\"%s\" fill=\"#12365a\" opacity=\"0.38\"/>\n", area
      printf "  <polyline points=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n", points, stroke

      mid = int((n + 1) / 2)
      printf "  <text x=\"%d\" y=\"%d\" fill=\"#95a7bc\" font-size=\"13\">window total %d</text>\n", left, stats_y, sum
      printf "  <text x=\"%d\" y=\"%d\" fill=\"#95a7bc\" font-size=\"13\" text-anchor=\"middle\">peak %d/hr</text>\n", int((left + right) / 2), stats_y, max
      printf "  <text x=\"%d\" y=\"%d\" fill=\"#95a7bc\" font-size=\"13\" text-anchor=\"end\">latest %d/hr</text>\n", right, stats_y, val[n]

      printf "  <text x=\"%d\" y=\"248\" fill=\"#89a0b8\" font-size=\"12\">%s</text>\n", left, esc(label[1])
      printf "  <text x=\"%d\" y=\"248\" fill=\"#89a0b8\" font-size=\"12\">%s</text>\n", int((left + right) / 2) - 44, esc(label[mid])
      printf "  <text x=\"%d\" y=\"248\" fill=\"#89a0b8\" font-size=\"12\">%s</text>\n", right - 84, esc(label[n])
      print "</svg>"
    }
  ' "${in}" > "${tmp}"
  chmod 0644 "${tmp}"
  mv -f "${tmp}" "${out}"
}

# Summary:
#   make_topn_tsv_bar_svg helper.
make_topn_tsv_bar_svg() {
  in="$1"
  out="$2"
  title="$3"
  accent="$4"
  tmp="$(mktemp "${out}.tmp.XXXXXX")"

  [ -s "${in}" ] || {
    make_empty_trend_svg "${out}" "${title}"
    rm -f "${tmp}"
    return 0
  }

  awk -F'\t' -v title="${title}" -v accent="${accent}" '
    function esc(s) {
      gsub(/&/, "\\&amp;", s)
      gsub(/</, "\\&lt;", s)
      gsub(/>/, "\\&gt;", s)
      return s
    }
    function short(s, n) {
      if (length(s) > n) return substr(s, 1, n - 3) "..."
      return s
    }
    NF >= 2 {
      if (n >= 8) next
      n++
      label[n] = $1
      val[n] = $2 + 0
      sum += val[n]
      if (n == 1 || val[n] > max) max = val[n]
    }
    END {
      w = 640
      h = 360
      left = 22
      label_w = 220
      bar_left = left + label_w + 14
      right = w - 20
      top = 64
      row_h = 28
      row_gap = 9
      bar_w = right - bar_left

      if (n < 1) {
        printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">", w, h, w, h
        printf "<rect x=\"0\" y=\"0\" width=\"%d\" height=\"%d\" fill=\"#0a1220\" rx=\"14\"/>", w, h
        printf "<text x=\"22\" y=\"38\" fill=\"#95a7bc\" font-size=\"18\">%s</text>", esc(title)
        printf "<text x=\"22\" y=\"74\" fill=\"#6f8298\" font-size=\"14\">no data available in this window</text>"
        print "</svg>"
        exit
      }
      if (max < 1) max = 1

      printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\" role=\"img\" aria-label=\"%s\">\n", w, h, w, h, esc(title)
      printf "  <rect x=\"0\" y=\"0\" width=\"%d\" height=\"%d\" fill=\"#071223\" rx=\"14\"/>\n", w, h
      printf "  <text x=\"22\" y=\"30\" fill=\"#b7c7d7\" font-size=\"16\">window total %d</text>\n", sum
      printf "  <text x=\"250\" y=\"30\" fill=\"#b7c7d7\" font-size=\"16\">top count %d</text>\n", max
      printf "  <text x=\"430\" y=\"30\" fill=\"#b7c7d7\" font-size=\"16\">entries %d</text>\n", n

      for (i = 1; i <= n; i++) {
        y = top + ((i - 1) * (row_h + row_gap))
        bw = (val[i] / max) * bar_w
        if (bw < 1 && val[i] > 0) bw = 1
        printf "  <text x=\"%d\" y=\"%.2f\" fill=\"#d8e6f4\" font-size=\"16\">%s</text>\n", left, y + 19, esc(short(label[i], 30))
        printf "  <rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%d\" fill=\"%s\" rx=\"5\"/>\n", bar_left, y, bw, row_h, accent
        printf "  <text x=\"%d\" y=\"%.2f\" fill=\"#f0f6ff\" font-size=\"16\" text-anchor=\"end\">%d</text>\n", right, y + 19, val[i]
      }
      print "</svg>"
    }
  ' "${in}" > "${tmp}"
  chmod 0644 "${tmp}"
  mv -f "${tmp}" "${out}"
}

# Summary:
#   render_page helper.
render_page() {
  path="$1"
  title="$2"
  tmp="$(mktemp "${path}.tmp.XXXXXX")"

  cat > "${tmp}" <<EOF_HEAD
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<style>
:root {
  --paper: #0b0f14;
  --paper-2: #0f1622;
  --ink: #f2f7ff;
  --muted: #b7c4d2;
  --line: rgba(166, 185, 206, 0.34);
  --accent: #b6ff3b;
  --accent-2: #4de1ff;
  --accent-3: #f5b942;
  --surface: rgba(10, 16, 24, 0.86);
  --surface-2: rgba(12, 20, 30, 0.90);
  --ok: #59f2c7;
  --warn: #f5b942;
  --bad: #ff6b6b;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  font-family: "Space Grotesk", "Avenir Next", "Segoe UI", sans-serif;
  font-size: 16px;
  line-height: 1.45;
  color: var(--ink);
  background:
    radial-gradient(900px 460px at 12% -10%, rgba(77, 225, 255, 0.12), transparent 60%),
    radial-gradient(800px 520px at 90% 0%, rgba(182, 255, 59, 0.10), transparent 60%),
    linear-gradient(180deg, var(--paper), var(--paper-2));
}
main {
  max-width: 1280px;
  margin: 0 auto;
  padding: 20px;
}
header {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  align-items: flex-end;
  flex-wrap: wrap;
  margin-bottom: 12px;
}
h1 {
  margin: 0;
  font-size: 2rem;
  letter-spacing: 0.03em;
}
.sub {
  color: var(--muted);
  font-size: 0.9rem;
}
nav {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
  margin: 10px 0 16px;
}
nav a {
  text-decoration: none;
  color: var(--ink);
  border: 1px solid var(--line);
  border-radius: 999px;
  padding: 5px 12px;
  background: rgba(11, 17, 26, 0.72);
  font-size: 0.84rem;
}
nav a:hover {
  border-color: rgba(77, 225, 255, 0.7);
  color: var(--accent-2);
}
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 12px;
}
.span-all { grid-column: 1 / -1; }
.grid-1 {
  display: grid;
  grid-template-columns: 1fr;
  gap: 12px;
}
.grid-2 {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(420px, 1fr));
  gap: 12px;
}
.card {
  background: var(--surface-2);
  border: 1px solid var(--line);
  border-radius: 14px;
  padding: 14px;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.32);
}
.card h2 {
  margin: 0 0 10px;
  font-size: 1.08rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: #d9e7f4;
}
.kpi {
  font-size: 2rem;
  font-weight: 700;
  line-height: 1.1;
}
.stat {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  border-top: 1px dashed rgba(166, 185, 206, 0.34);
  padding-top: 7px;
  margin-top: 7px;
  font-size: 0.98rem;
}
.label { color: var(--muted); }
.mono {
  font-family: "Space Mono", "IBM Plex Mono", Menlo, Consolas, monospace;
  font-size: 0.90rem;
  color: #d1deea;
  word-break: break-word;
}
.chip {
  display: inline-block;
  padding: 2px 10px;
  border-radius: 999px;
  border: 1px solid transparent;
  font-size: 0.78rem;
  font-weight: 600;
}
.chip-ok { color: #052e27; background: var(--ok); border-color: #8ef7da; }
.chip-warn { color: #322100; background: var(--warn); border-color: #ffd98c; }
.chip-bad { color: #2f0000; background: var(--bad); border-color: #ffb0b0; }
.chip-neutral { color: #d6e3ef; background: #243247; border-color: #425878; }
.table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.96rem;
}
.table th, .table td {
  border-bottom: 1px solid rgba(148, 163, 184, 0.24);
  text-align: left;
  padding: 9px 6px;
  vertical-align: top;
}
.table th { color: #c5d4e3; font-weight: 600; }
.ticket-kpi-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 10px;
  margin-top: 10px;
}
.ticket-kpi {
  border: 1px solid rgba(148, 163, 184, 0.22);
  border-radius: 12px;
  padding: 10px 12px;
  background: rgba(9, 16, 25, 0.72);
}
.ticket-kpi-label {
  color: var(--muted);
  font-size: 0.78rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}
.ticket-kpi-value {
  margin-top: 6px;
  font-size: 1.16rem;
  font-weight: 700;
  color: #edf7ff;
}
.ticket-stream {
  display: grid;
  gap: 12px;
  margin-top: 12px;
}
.ticket-event {
  border: 1px solid rgba(148, 163, 184, 0.26);
  border-left: 4px solid #425878;
  border-radius: 14px;
  padding: 14px;
  background:
    linear-gradient(180deg, rgba(14, 23, 35, 0.94), rgba(9, 16, 26, 0.88));
  box-shadow: 0 12px 30px rgba(0, 0, 0, 0.22);
}
.ticket-event.sev-ok { border-left-color: var(--ok); }
.ticket-event.sev-warn { border-left-color: var(--warn); }
.ticket-event.sev-bad { border-left-color: var(--bad); }
.ticket-event.sev-neutral { border-left-color: #425878; }
.ticket-event-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
  flex-wrap: wrap;
}
.ticket-event-title {
  font-size: 1.05rem;
  font-weight: 700;
  color: #eef7ff;
  max-width: 760px;
}
.ticket-event-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.ticket-meta-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 10px;
  margin-top: 12px;
}
.ticket-meta {
  border: 1px solid rgba(148, 163, 184, 0.18);
  border-radius: 10px;
  padding: 8px 10px;
  background: rgba(7, 18, 35, 0.56);
}
.ticket-meta-label,
.ticket-block-label {
  color: var(--muted);
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}
.ticket-meta-value {
  margin-top: 4px;
  color: #edf5ff;
}
.ticket-block-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 10px;
  margin-top: 12px;
}
.ticket-block {
  border: 1px solid rgba(148, 163, 184, 0.18);
  border-radius: 12px;
  padding: 10px 12px;
  background: rgba(7, 18, 35, 0.46);
  min-width: 0;
}
.ticket-block-wide {
  grid-column: 1 / -1;
}
.ticket-block-value {
  margin-top: 6px;
  color: #deebf7;
  overflow-wrap: anywhere;
}
.ticket-empty {
  color: var(--muted);
  padding: 6px 2px 2px;
}
.methods-table th:nth-child(1), .methods-table td:nth-child(1) { width: 190px; }
.methods-table th:nth-child(2), .methods-table td:nth-child(2) { width: 90px; text-align: right; }
.methods-table td:nth-child(3) { color: #d2deea; }
.dns-domain-table th:nth-child(1), .dns-domain-table td:nth-child(1) {
  width: 240px;
  min-width: 240px;
  white-space: nowrap;
}
.dns-domain-table th:nth-child(2), .dns-domain-table td:nth-child(2) {
  width: 70px;
  text-align: right;
}
.dns-domain-table td:nth-child(3) {
  width: 320px;
}
.dns-domain-table td:nth-child(4) {
  word-break: break-all;
}
.topn-data-table th:nth-child(2), .topn-data-table td:nth-child(2) {
  width: 90px;
  text-align: right;
}
.note {
  font-size: 0.95rem;
  color: #c4d1df;
  margin-top: 8px;
}
.list {
  margin: 0;
  padding-left: 18px;
  font-size: 0.9rem;
}
.trend-lg {
  width: 100%;
  min-height: 340px;
  border-radius: 12px;
  border: 1px solid #203247;
  background: #071223;
}
.pfimg {
  width: 100%;
  min-height: 320px;
  object-fit: contain;
  border-radius: 12px;
  border: 1px solid #203247;
  background: #071223;
}
.pfimg-xl {
  width: 100%;
  min-height: 460px;
  object-fit: contain;
  border-radius: 12px;
  border: 1px solid #203247;
  background: #071223;
}
footer {
  margin-top: 16px;
  color: var(--muted);
  font-size: 0.78rem;
}
@media (max-width: 760px) {
  h1 { font-size: 1.5rem; }
  .kpi { font-size: 1.5rem; }
  .trend-lg, .pfimg { min-height: 260px; }
  .pfimg-xl { min-height: 280px; }
  .grid-2 { grid-template-columns: 1fr; }
  .ticket-kpi-grid,
  .ticket-meta-grid,
  .ticket-block-grid {
    grid-template-columns: 1fr;
  }
  .dns-domain-table th:nth-child(1), .dns-domain-table td:nth-child(1) {
    width: auto;
    min-width: 0;
    white-space: normal;
  }
}
</style>
</head>
<body>
<main>
<header>
  <div>
    <h1>${MONITORING_SERVER_NAME:-mail.example.com} monitor</h1>
    <div class="sub">openbsd-native telemetry snapshot · updated ${timestamp_iso}</div>
  </div>
  <div class="sub">host ${host}</div>
</header>
<nav>
  <a href="index.html">overview</a>
  <a href="host.html">host</a>
  <a href="network.html">network</a>
  <a href="pf.html">pf</a>
  <a href="mail.html">mail</a>
  <a href="rspamd.html">rspamd</a>
  <a href="dovecot.html">dovecot</a>
  <a href="postfix.html">postfix</a>
  <a href="web.html">web</a>
  <a href="dns.html">dns</a>
  <a href="ids.html">ids</a>
  <a href="vpn.html">vpn</a>
  <a href="storage.html">storage</a>
  <a href="backups.html">backups</a>
  <a href="agent.html">agent</a>
  <a href="changes.html">changes</a>
</nav>
EOF_HEAD

  cat >> "${tmp}"

  cat >> "${tmp}" <<'EOF_FOOT'
<footer>
  generated by obsd_monitor_render.ksh from /var/www/monitor/data/snapshots and log-derived trend snapshots
</footer>
</main>
</body>
</html>
EOF_FOOT
  chmod 0644 "${tmp}"
  mv -f "${tmp}" "${path}"
}

host="$(kv_get "${latest}" host unknown)"
timestamp_iso="$(kv_get "${latest}" timestamp_iso unknown)"

load_1="$(kv_get "${latest}" load_1 0)"
load_5="$(kv_get "${latest}" load_5 0)"
load_15="$(kv_get "${latest}" load_15 0)"
cpu_idle_pct="$(to_int "$(kv_get "${latest}" cpu_idle_pct 0)")"
root_use_pct="$(to_int "$(kv_get "${latest}" root_use_pct 0)")"
var_use_pct="$(to_int "$(kv_get "${latest}" var_use_pct 0)")"
home_use_pct="$(to_int "$(kv_get "${latest}" home_use_pct 0)")"
svc_total="$(to_int "$(kv_get "${latest}" svc_total 0)")"
svc_ok="$(to_int "$(kv_get "${latest}" svc_ok 0)")"
svc_fail="$(to_int "$(kv_get "${latest}" svc_fail 0)")"
svc_fail_list="$(html_escape "$(kv_get "${latest}" svc_fail_list none)")"
svc_non_daemon_count="$(to_int "$(kv_get "${latest}" svc_non_daemon_count 0)")"
svc_non_daemon_list="$(html_escape "$(kv_get "${latest}" svc_non_daemon_list none)")"

pf_enabled="$(to_int "$(kv_get "${latest}" pf_enabled 0)")"
pf_states="$(to_int "$(kv_get "${latest}" pf_states 0)")"
pf_tables="$(to_int "$(kv_get "${latest}" pf_tables 0)")"
pf_packets_in_block="$(to_int "$(kv_get "${latest}" pf_packets_in_block 0)")"
table_suricata_watch="$(to_int "$(kv_get "${latest}" table_suricata_watch 0)")"
table_suricata_block="$(to_int "$(kv_get "${latest}" table_suricata_block 0)")"
table_suricata_allow="$(to_int "$(kv_get "${latest}" table_suricata_allow 0)")"

mail_accepted="$(to_int "$(kv_get "${latest}" mail_accepted 0)")"
mail_rejected="$(to_int "$(kv_get "${latest}" mail_rejected 0)")"
mail_queue="$(to_int "$(kv_get "${latest}" mail_queue 0)")"
mail_accepted_24h="$(to_int "$(kv_get "${latest}" mail_accepted_24h 0)")"
mail_accepted_1h="$(to_int "$(kv_get "${latest}" mail_accepted_1h 0)")"
mail_connect_24h="$(to_int "$(kv_get "${latest}" mail_connect_24h 0)")"
mail_connect_1h="$(to_int "$(kv_get "${latest}" mail_connect_1h 0)")"
mail_rejected_24h="$(to_int "$(kv_get "${latest}" mail_rejected_24h 0)")"
mail_rejected_1h="$(to_int "$(kv_get "${latest}" mail_rejected_1h 0)")"
mail_noncompliant_attempts_24h="$(to_int "$(kv_get "${latest}" mail_noncompliant_attempts_24h 0)")"
mail_noncompliant_top_methods_raw="$(kv_get "${latest}" mail_noncompliant_top_methods none)"
mail_noncompliant_top_methods_inline="$(html_escape "${mail_noncompliant_top_methods_raw}")"
mail_noncompliant_method_rows="$(build_mail_noncompliant_method_rows "${MAIL_NONCOMPLIANT_METHODS_TSV}")"
mail_connection_catalog_rows="$(build_topn_rows_from_tsv "${MAIL_CONNECTION_CATALOG_TSV}" 8 "NO_EVENT")"
mail_connection_source_rows="$(build_topn_rows_from_tsv "${MAIL_CONNECTION_SOURCES_TSV}" 8 "NO_SOURCE")"
mail_connection_catalog_top_inline="$(html_escape "$(kv_get "${latest}" mail_connection_catalog_top none)")"
mail_connection_source_top_inline="$(html_escape "$(kv_get "${latest}" mail_connection_source_top none)")"
mail_connection_events_total="$(to_int "$(kv_get "${latest}" mail_connection_events_total 0)")"
mail_connection_rejected_total="$(to_int "$(kv_get "${latest}" mail_connection_rejected_total 0)")"
mail_connection_noncompliant_total="$(to_int "$(kv_get "${latest}" mail_connection_noncompliant_total 0)")"
mail_connection_lines_scanned="$(to_int "$(kv_get "${latest}" mail_connection_lines_scanned 0)")"
mail_log_files_scanned="$(to_int "$(kv_get "${latest}" mail_log_files_scanned 0)")"

suricata_alerts="$(to_int "$(kv_get "${latest}" suricata_alerts 0)")"
suricata_alerts_24h="$(to_int "$(kv_get "${latest}" suricata_alerts_24h 0)")"
suricata_alerts_1h="$(to_int "$(kv_get "${latest}" suricata_alerts_1h 0)")"
suricata_blocked_totals="$(to_int "$(kv_get "${latest}" suricata_blocked_totals 0)")"
suricata_top_blocked_sig_raw="$(kv_get "${latest}" suricata_top_blocked_sig none)"
suricata_top_blocked_sig="$(html_escape "${suricata_top_blocked_sig_raw}")"
suricata_top_source_ip_raw="$(kv_get "${latest}" suricata_top_source_ip none)"
suricata_top_source_ip="$(html_escape "${suricata_top_source_ip_raw}")"
suricata_top_source_hits="$(to_int "$(kv_get "${latest}" suricata_top_source_hits 0)")"
suricata_last_blocked_ts_raw="$(kv_get "${latest}" suricata_last_blocked_ts none)"
suricata_last_blocked_ts="$(html_escape "${suricata_last_blocked_ts_raw}")"
suricata_status_raw="$(kv_get "${latest}" suricata_status unknown)"
suricata_status="$(html_escape "${suricata_status_raw}")"
suricata_version="$(html_escape "$(kv_get "${latest}" suricata_version unknown)")"
suricata_log_dir="$(html_escape "$(kv_get "${latest}" suricata_log_dir /var/log/suricata)")"
suricata_event_total="$(to_int "$(kv_get "${latest}" suricata_event_total 0)")"
suricata_event_types_top_raw="$(kv_get "${latest}" suricata_event_types_top none)"
suricata_protocol_top_raw="$(kv_get "${latest}" suricata_protocol_top none)"
suricata_action_top_raw="$(kv_get "${latest}" suricata_action_top none)"
suricata_keywords_top_raw="$(kv_get "${latest}" suricata_keywords_top none)"
suricata_top_signatures_text_raw="$(kv_get "${latest}" suricata_top_signatures_text none)"
suricata_top_sources_text_raw="$(kv_get "${latest}" suricata_top_sources_text none)"
suricata_blocked_sample_count="$(to_int "$(kv_get "${latest}" suricata_blocked_sample_count 0)")"
suricata_alert_sample_count="$(to_int "$(kv_get "${latest}" suricata_alert_sample_count 0)")"
suricata_recent_blocked_raw="$(kv_get "${latest}" suricata_recent_blocked none)"
suricata_recent_alerts_raw="$(kv_get "${latest}" suricata_recent_alerts none)"
suricata_eve2pf_mode_raw="$(kv_get "${latest}" suricata_eve2pf_mode unknown)"
suricata_eve2pf_table_raw="$(kv_get "${latest}" suricata_eve2pf_table unknown)"
suricata_eve2pf_mode="$(html_escape "${suricata_eve2pf_mode_raw}")"
suricata_eve2pf_table="$(html_escape "${suricata_eve2pf_table_raw}")"
suricata_eve2pf_candidates="$(to_int "$(kv_get "${latest}" suricata_eve2pf_candidates 0)")"
suricata_eve2pf_window_s="$(to_int "$(kv_get "${latest}" suricata_eve2pf_window_s 0)")"
suricata_eve2pf_last_ts="$(html_escape "$(kv_get "${latest}" suricata_eve2pf_last_ts none)")"
suricata_eve2pf_log_age_min="$(to_int "$(kv_get "${latest}" suricata_eve2pf_log_age_min -1)")"

cron_fail_count="$(to_int "$(kv_get "${latest}" cron_fail_count 0)")"
cron_warn_count="$(to_int "$(kv_get "${latest}" cron_warn_count 0)")"
cron_fail_jobs="$(html_escape "$(kv_get "${latest}" cron_fail_jobs none)")"
cron_warn_jobs="$(html_escape "$(kv_get "${latest}" cron_warn_jobs none)")"
cron_fail_context="$(html_escape "$(kv_get "${latest}" cron_fail_context none)")"
cron_warn_context="$(html_escape "$(kv_get "${latest}" cron_warn_context none)")"
sbom_daily_status_raw="$(kv_get "${latest}" sbom_daily_status UNKNOWN)"
sbom_weekly_status_raw="$(kv_get "${latest}" sbom_weekly_status UNKNOWN)"
sbom_daily_status="$(html_escape "${sbom_daily_status_raw}")"
sbom_weekly_status="$(html_escape "${sbom_weekly_status_raw}")"
sbom_daily_exit_code="$(to_int "$(kv_get "${latest}" sbom_daily_exit_code 0)")"
sbom_weekly_exit_code="$(to_int "$(kv_get "${latest}" sbom_weekly_exit_code 0)")"
sbom_daily_age_min="$(to_int "$(kv_get "${latest}" sbom_daily_age_min -1)")"
sbom_weekly_age_min="$(to_int "$(kv_get "${latest}" sbom_weekly_age_min -1)")"
sbom_capability_mode_raw="$(kv_get "${latest}" sbom_capability_mode unknown)"
sbom_capability_mode="$(html_escape "${sbom_capability_mode_raw}")"
cron_mailto_ops="$(to_int "$(kv_get "${latest}" cron_mailto_ops 0)")"
cron_weekly_maintenance_4am="$(to_int "$(kv_get "${latest}" cron_weekly_maintenance_4am 0)")"
cron_weekly_maintenance_apply_wrapped="$(to_int "$(kv_get "${latest}" cron_weekly_maintenance_apply_wrapped 0)")"
cron_weekly_maintenance_post_reboot_wrapped="$(to_int "$(kv_get "${latest}" cron_weekly_maintenance_post_reboot_wrapped 0)")"
cron_daily_patch_scan="$(to_int "$(kv_get "${latest}" cron_daily_patch_scan 0)")"
cron_regression_gate="$(to_int "$(kv_get "${latest}" cron_regression_gate 0)")"
suricata_mode_block_cron="$(to_int "$(kv_get "${latest}" suricata_mode_block_cron 0)")"
cron_html_report_count="$(to_int "$(kv_get "${latest}" cron_html_report_count 0)")"
cron_reports_24h="$(to_int "$(kv_get "${latest}" cron_reports_24h 0)")"
cron_report_latest_age_min="$(to_int "$(kv_get "${latest}" cron_report_latest_age_min -1)")"
weekly_maintenance_structured_report="$(to_int "$(kv_get "${latest}" weekly_maintenance_structured_report 0)")"
weekly_maintenance_apply_status_raw="$(kv_get "${latest}" weekly_maintenance_apply_status UNKNOWN)"
weekly_maintenance_apply_status="$(html_escape "${weekly_maintenance_apply_status_raw}")"
weekly_maintenance_apply_age_min="$(to_int "$(kv_get "${latest}" weekly_maintenance_apply_age_min -1)")"
weekly_maintenance_post_status_raw="$(kv_get "${latest}" weekly_maintenance_post_status UNKNOWN)"
weekly_maintenance_post_status="$(html_escape "${weekly_maintenance_post_status_raw}")"
weekly_maintenance_post_age_min="$(to_int "$(kv_get "${latest}" weekly_maintenance_post_age_min -1)")"
weekly_maintenance_apply_age_display="${weekly_maintenance_apply_age_min}m"
[ "${weekly_maintenance_apply_age_min}" -lt 0 ] && weekly_maintenance_apply_age_display="n/a"
weekly_maintenance_post_age_display="${weekly_maintenance_post_age_min}m"
[ "${weekly_maintenance_post_age_min}" -lt 0 ] && weekly_maintenance_post_age_display="n/a"
weekly_maintenance_log_age_min="$(to_int "$(kv_get "${latest}" weekly_maintenance_log_age_min -1)")"
maint_last_log_age_min="$(to_int "$(kv_get "${latest}" maint_last_log_age_min -1)")"
regression_gate_log_age_min="$(to_int "$(kv_get "${latest}" regression_gate_log_age_min -1)")"
weekly_maintenance_pending="$(to_int "$(kv_get "${latest}" weekly_maintenance_pending 0)")"
maint_last_regression_pass="$(to_int "$(kv_get "${latest}" maint_last_regression_pass 0)")"
doas_policy_weekly_status_raw="$(kv_get "${latest}" doas_policy_weekly_status UNKNOWN)"
doas_policy_weekly_status="$(html_escape "${doas_policy_weekly_status_raw}")"
doas_policy_weekly_age_min="$(to_int "$(kv_get "${latest}" doas_policy_weekly_age_min -1)")"
ssh_hardening_weekly_status_raw="$(kv_get "${latest}" ssh_hardening_weekly_status UNKNOWN)"
ssh_hardening_weekly_status="$(html_escape "${ssh_hardening_weekly_status_raw}")"
ssh_hardening_weekly_age_min="$(to_int "$(kv_get "${latest}" ssh_hardening_weekly_age_min -1)")"
ssh_hardening_state_raw="$(kv_get "${latest}" ssh_hardening_state unknown)"
ssh_hardening_state="$(html_escape "${ssh_hardening_state_raw}")"
ssh_hardening_mismatch_count="$(to_int "$(kv_get "${latest}" ssh_hardening_mismatch_count 0)")"
ssh_hardening_mismatches_raw="$(kv_get "${latest}" ssh_hardening_mismatches none)"
ssh_hardening_mismatches="$(html_escape "${ssh_hardening_mismatches_raw}")"
ssh_hardening_syntax_ok="$(to_int "$(kv_get "${latest}" ssh_hardening_syntax_ok 0)")"
ssh_hardening_service_ok="$(to_int "$(kv_get "${latest}" ssh_hardening_service_ok 0)")"
ssh_hardening_listener_ok="$(to_int "$(kv_get "${latest}" ssh_hardening_listener_ok 0)")"
doas_policy_state_raw="$(kv_get "${latest}" doas_policy_state unknown)"
doas_policy_state="$(html_escape "${doas_policy_state_raw}")"
doas_live_valid="$(to_int "$(kv_get "${latest}" doas_live_valid 0)")"
doas_policy_drift="$(to_int "$(kv_get "${latest}" doas_policy_drift 0)")"
doas_policy_missing_rules_raw="$(kv_get "${latest}" doas_policy_missing_rules none)"
doas_policy_missing_rules="$(html_escape "${doas_policy_missing_rules_raw}")"
doas_policy_extra_rules_raw="$(kv_get "${latest}" doas_policy_extra_rules none)"
doas_policy_extra_rules="$(html_escape "${doas_policy_extra_rules_raw}")"
doas_automation_overlay_present="$(to_int "$(kv_get "${latest}" doas_automation_overlay_present 0)")"
maint_plan_status_raw="$(kv_get "${latest}" maint_plan_status UNKNOWN)"
maint_plan_status="$(html_escape "${maint_plan_status_raw}")"
maint_plan_exit_code="$(to_int "$(kv_get "${latest}" maint_plan_exit_code 0)")"
maint_plan_age_min="$(to_int "$(kv_get "${latest}" maint_plan_age_min -1)")"
maint_plan_log_file_raw="$(kv_get "${latest}" maint_plan_log_file none)"
maint_plan_log_file="$(html_escape "${maint_plan_log_file_raw}")"
syspatch_pending_count="$(to_int "$(kv_get "${latest}" syspatch_pending_count 0)")"
syspatch_pending_list_raw="$(kv_get "${latest}" syspatch_pending_list none)"
syspatch_pending_list="$(html_escape "${syspatch_pending_list_raw}")"
syspatch_installed_count="$(to_int "$(kv_get "${latest}" syspatch_installed_count 0)")"
syspatch_up_to_date="$(to_int "$(kv_get "${latest}" syspatch_up_to_date 0)")"
syspatch_data_source_raw="$(kv_get "${latest}" syspatch_data_source unknown)"
syspatch_data_source="$(html_escape "${syspatch_data_source_raw}")"
syspatch_check_status_raw="$(kv_get "${latest}" syspatch_check_status unknown)"
syspatch_check_status="$(html_escape "${syspatch_check_status_raw}")"
syspatch_check_rc="$(to_int "$(kv_get "${latest}" syspatch_check_rc 0)")"
pkg_upgrade_runs_total="$(to_int "$(kv_get "${latest}" pkg_upgrade_runs_total 0)")"
pkg_upgrade_last_run_ts_raw="$(kv_get "${latest}" pkg_upgrade_last_run_ts none)"
pkg_upgrade_last_run_ts="$(html_escape "${pkg_upgrade_last_run_ts_raw}")"
pkg_upgrade_last_run_age_min="$(to_int "$(kv_get "${latest}" pkg_upgrade_last_run_age_min -1)")"
pkg_upgrade_last_apply_ts_raw="$(kv_get "${latest}" pkg_upgrade_last_apply_ts none)"
pkg_upgrade_last_apply_ts="$(html_escape "${pkg_upgrade_last_apply_ts_raw}")"
pkg_upgrade_last_apply_age_min="$(to_int "$(kv_get "${latest}" pkg_upgrade_last_apply_age_min -1)")"
pkg_upgrade_last_post_verify_ts_raw="$(kv_get "${latest}" pkg_upgrade_last_post_verify_ts none)"
pkg_upgrade_last_post_verify_ts="$(html_escape "${pkg_upgrade_last_post_verify_ts_raw}")"
pkg_upgrade_last_post_verify_status_raw="$(kv_get "${latest}" pkg_upgrade_last_post_verify_status none)"
pkg_upgrade_last_post_verify_status="$(html_escape "${pkg_upgrade_last_post_verify_status_raw}")"
pkg_add_u_recent="$(to_int "$(kv_get "${latest}" pkg_add_u_recent 0)")"
pkg_snapshot_age_min="$(to_int "$(kv_get "${latest}" pkg_snapshot_age_min -1)")"
pkg_snapshot_count="$(to_int "$(kv_get "${latest}" pkg_snapshot_count 0)")"
sbom_report_age_min="$(to_int "$(kv_get "${latest}" sbom_report_age_min -1)")"
sbom_scanner_raw="$(kv_get "${latest}" sbom_scanner unknown)"
sbom_scanner="$(html_escape "${sbom_scanner_raw}")"
sbom_package_count="$(to_int "$(kv_get "${latest}" sbom_package_count 0)")"
sbom_severity_critical="$(to_int "$(kv_get "${latest}" sbom_severity_critical 0)")"
sbom_severity_high="$(to_int "$(kv_get "${latest}" sbom_severity_high 0)")"
sbom_severity_medium="$(to_int "$(kv_get "${latest}" sbom_severity_medium 0)")"
sbom_severity_low="$(to_int "$(kv_get "${latest}" sbom_severity_low 0)")"
sbom_severity_unknown="$(to_int "$(kv_get "${latest}" sbom_severity_unknown 0)")"
sbom_vuln_total="$(to_int "$(kv_get "${latest}" sbom_vuln_total 0)")"
sbom_exceptions_total="$(to_int "$(kv_get "${latest}" sbom_exceptions_total 0)")"
sbom_exceptions_expired="$(to_int "$(kv_get "${latest}" sbom_exceptions_expired 0)")"
sbom_exceptions_invalid="$(to_int "$(kv_get "${latest}" sbom_exceptions_invalid 0)")"
cve_mapping_supported="$(to_int "$(kv_get "${latest}" cve_mapping_supported 0)")"
cve_associated_findings="$(to_int "$(kv_get "${latest}" cve_associated_findings -1)")"
cve_association_status_raw="$(kv_get "${latest}" cve_association_status unknown)"
cve_association_status="$(html_escape "${cve_association_status_raw}")"
cve_summary_note_raw="$(kv_get "${latest}" cve_summary_note none)"
cve_summary_note="$(html_escape "${cve_summary_note_raw}")"
report_trust_state_raw="$(kv_get "${latest}" report_trust_state unknown)"
report_trust_state="$(html_escape "${report_trust_state_raw}")"
report_trust_false_green_count="$(to_int "$(kv_get "${latest}" report_trust_false_green_count 0)")"
report_trust_advisory_count="$(to_int "$(kv_get "${latest}" report_trust_advisory_count 0)")"
report_trust_reasons_raw="$(kv_get "${latest}" report_trust_reasons none)"
report_trust_reasons="$(html_escape "${report_trust_reasons_raw}")"
lifecycle_gap_state_raw="$(kv_get "${latest}" lifecycle_gap_state unknown)"
lifecycle_gap_state="$(html_escape "${lifecycle_gap_state_raw}")"
lifecycle_gap_reasons_raw="$(kv_get "${latest}" lifecycle_gap_reasons none)"
lifecycle_gap_reasons="$(html_escape "${lifecycle_gap_reasons_raw}")"
verify_status_raw="$(kv_get "${latest}" verify_status unknown)"
verify_status="$(html_escape "${verify_status_raw}")"
verify_public_ports="$(html_escape "$(kv_get "${latest}" verify_public_ports none)")"

public_tcp_count="$(to_int "$(kv_get "${latest}" public_tcp_count 0)")"
public_udp_count="$(to_int "$(kv_get "${latest}" public_udp_count 0)")"
public_tcp_list="$(html_escape "$(kv_get "${latest}" public_tcp_list none)")"
public_udp_list="$(html_escape "$(kv_get "${latest}" public_udp_list none)")"

tcp_listen_count="$(to_int "$(kv_get "${latest}" tcp_listen_count 0)")"
udp_listener_count="$(to_int "$(kv_get "${latest}" udp_listener_count 0)")"

wg_iface_present="$(to_int "$(kv_get "${latest}" wg_iface_present 0)")"
wg_peer_count="$(to_int "$(kv_get "${latest}" wg_peer_count 0)")"
wg_active_peer_count="$(to_int "$(kv_get "${latest}" wg_active_peer_count 0)")"

backup_job_rows="$(build_backup_job_rows)"
network_interface_issue_rows="$(build_network_interface_issue_rows)"
network_log_issue_rows="$(build_network_log_issue_rows)"

backup_mailstack_age_min="$(to_int "$(kv_get "${latest}" backup_mailstack_age_min -1)")"
backup_mysql_age_min="$(to_int "$(kv_get "${latest}" backup_mysql_age_min -1)")"
backup_mailstack_latest_path="$(kv_get "${latest}" backup_mailstack_latest_path none)"
backup_mysql_latest_path="$(kv_get "${latest}" backup_mysql_latest_path none)"
dns_vultr_manifest_path="$(kv_get "${latest}" dns_vultr_manifest_path none)"
dns_vultr_snapshot_dir="$(kv_get "${latest}" dns_vultr_snapshot_dir none)"
dns_vultr_age_min="$(to_int "$(kv_get "${latest}" dns_vultr_age_min -1)")"
dns_vultr_domain_count="$(to_int "$(kv_get "${latest}" dns_vultr_domain_count 0)")"
dns_vultr_record_count="$(to_int "$(kv_get "${latest}" dns_vultr_record_count 0)")"
dns_vultr_generated_at="$(kv_get "${latest}" dns_vultr_generated_at unknown)"
dns_vultr_output_dir="$(kv_get "${latest}" dns_vultr_output_dir none)"
pfstats_age_min="$(to_int "$(kv_get "${latest}" pfstats_age_min -1)")"
mailstats_age_min="$(to_int "$(kv_get "${latest}" mailstats_age_min -1)")"
suricata_age_min="$(to_int "$(kv_get "${latest}" suricata_age_min -1)")"
verify_age_min="$(to_int "$(kv_get "${latest}" verify_age_min -1)")"
mail_trend_age_min="$(to_int "$(kv_get "${latest}" mail_trend_age_min -1)")"
mail_connect_trend_age_min="$(to_int "$(kv_get "${latest}" mail_connect_trend_age_min -1)")"
mail_reject_trend_age_min="$(to_int "$(kv_get "${latest}" mail_reject_trend_age_min -1)")"
mail_noncompliant_methods_age_min="$(to_int "$(kv_get "${latest}" mail_noncompliant_methods_age_min -1)")"
mail_connection_catalog_age_min="$(to_int "$(kv_get "${latest}" mail_connection_catalog_age_min -1)")"
mail_connection_sources_age_min="$(to_int "$(kv_get "${latest}" mail_connection_sources_age_min -1)")"
suricata_trend_age_min="$(to_int "$(kv_get "${latest}" suricata_trend_age_min -1)")"

rspamd_reject="$(to_int "$(kv_get "${latest}" rspamd_reject 0)")"
rspamd_add_header="$(to_int "$(kv_get "${latest}" rspamd_add_header 0)")"
rspamd_greylist="$(to_int "$(kv_get "${latest}" rspamd_greylist 0)")"
rspamd_soft_reject="$(to_int "$(kv_get "${latest}" rspamd_soft_reject 0)")"
vt_checks="$(to_int "$(kv_get "${latest}" vt_checks 0)")"
vt_errors="$(to_int "$(kv_get "${latest}" vt_errors 0)")"

nginx_conf_ok="$(to_int "$(kv_get "${latest}" nginx_conf_ok 0)")"
nginx_https_wg_listener="$(to_int "$(kv_get "${latest}" nginx_https_wg_listener 0)")"
nginx_https_loop_listener="$(to_int "$(kv_get "${latest}" nginx_https_loop_listener 0)")"

web_primary_host_raw="none"
web_primary_host="none"
web_url_total=0
web_url_up=0
web_url_policy=0
web_url_restricted=0
web_url_missing=0
web_url_down=0
web_url_rows=""
web_url_probe_note="nginx config unavailable for url probing"
web_https_probe_ip="$(pick_probe_ip_for_port 443)"
web_http_probe_ip="$(pick_probe_ip_for_port 80)"
web_nginx_dump="$(mktemp /tmp/obsd-monitor-nginx.dump.XXXXXX)"
web_urls_tmp="$(mktemp /tmp/obsd-monitor-web-urls.XXXXXX)"
web_inventory_host_default="${WEB_INVENTORY_HOST:-${MONITORING_SERVER_NAME:-mail.example.com}}"

if command -v nginx >/dev/null 2>&1 && nginx -T > "${web_nginx_dump}" 2>/dev/null; then
  web_primary_host_raw="$(awk '
    /^[[:space:]]*server_name[[:space:]]+/ {
      line=$0
      sub(/#.*/, "", line)
      gsub(/;/, "", line)
      sub(/^[[:space:]]*server_name[[:space:]]+/, "", line)
      n=split(line, a, /[[:space:]]+/)
      for (i=1; i<=n; i++) {
        tok=tolower(a[i])
        if (tok=="" || tok=="_" || tok ~ /^[0-9.]+$/) continue
        if (tok ~ /\./) {
          print tok
          exit
        }
      }
    }
  ' "${web_nginx_dump}")"
  [ -n "${web_primary_host_raw}" ] || web_primary_host_raw="${web_inventory_host_default}"
else
  web_primary_host_raw="${web_inventory_host_default}"
fi
web_primary_host="${web_primary_host_raw}"

cat > "${web_urls_tmp}" <<EOF_WEB_URLS
https://${web_primary_host}
https://${web_primary_host}/sogo
https://${web_primary_host}/postfixadmin
https://${web_primary_host}/rspamd
https://${web_primary_host}/_ops/monitor/
https://${web_primary_host}/_ops/monitor/index.html
https://${web_primary_host}/_ops/monitor/host.html
https://${web_primary_host}/_ops/monitor/network.html
https://${web_primary_host}/_ops/monitor/pf.html
https://${web_primary_host}/_ops/monitor/mail.html
https://${web_primary_host}/_ops/monitor/rspamd.html
https://${web_primary_host}/_ops/monitor/dovecot.html
https://${web_primary_host}/_ops/monitor/postfix.html
https://${web_primary_host}/_ops/monitor/web.html
https://${web_primary_host}/_ops/monitor/dns.html
https://${web_primary_host}/_ops/monitor/ids.html
https://${web_primary_host}/_ops/monitor/vpn.html
https://${web_primary_host}/_ops/monitor/storage.html
https://${web_primary_host}/_ops/monitor/backups.html
https://${web_primary_host}/_ops/monitor/agent.html
https://${web_primary_host}/_ops/monitor/changes.html
EOF_WEB_URLS

while IFS= read -r _url; do
  [ -n "${_url}" ] || continue
  _scheme="${_url%%://*}"
  _rest="${_url#*://}"
  _host="${_rest%%/*}"
  if [ "${_rest}" = "${_host}" ]; then
    _path="/"
  else
    _path="/${_rest#*/}"
  fi

  _probe_port=80
  _probe_ip="${web_http_probe_ip}"
  if [ "${_scheme}" = "https" ]; then
    _probe_port=443
    _probe_ip="${web_https_probe_ip}"
  fi

  _service="$(web_service_label "${_path}")"
  _expectation="$(web_url_expected_policy "${_path}")"
  _http_code="000"
  if [ "${_path}" = "/brevo/webhook" ]; then
    _http_code="$(curl -sk --connect-timeout 3 --max-time 8 -X POST --data '' \
      --resolve "${_host}:${_probe_port}:${_probe_ip}" \
      -o /dev/null -w '%{http_code}' "${_url}" 2>/dev/null || printf '000')"
  else
    _http_code="$(curl -skL --connect-timeout 3 --max-time 8 \
      --resolve "${_host}:${_probe_port}:${_probe_ip}" \
      -o /dev/null -w '%{http_code}' "${_url}" 2>/dev/null || printf '000')"
  fi

  _url_state="unknown"
  case "${_expectation}" in
    protected)
      case "${_http_code}" in
        401|403|405)
          _url_state="policy_enforced"
          web_url_policy=$((web_url_policy + 1))
          ;;
        2*|3*)
          _url_state="up"
          web_url_up=$((web_url_up + 1))
          ;;
        404)
          _url_state="missing"
          web_url_missing=$((web_url_missing + 1))
          ;;
        000|5*)
          _url_state="down"
          web_url_down=$((web_url_down + 1))
          ;;
        *)
          _url_state="restricted"
          web_url_restricted=$((web_url_restricted + 1))
          ;;
      esac
      ;;
    webhook)
      case "${_http_code}" in
        2*|3*|400|401|403|405)
          _url_state="policy_enforced"
          web_url_policy=$((web_url_policy + 1))
          ;;
        000|5*)
          _url_state="down"
          web_url_down=$((web_url_down + 1))
          ;;
        *)
          _url_state="restricted"
          web_url_restricted=$((web_url_restricted + 1))
          ;;
      esac
      ;;
    optional)
      case "${_http_code}" in
        2*|3*)
          _url_state="up"
          web_url_up=$((web_url_up + 1))
          ;;
        404)
          _url_state="missing"
          web_url_missing=$((web_url_missing + 1))
          ;;
        401|403|405)
          _url_state="policy_enforced"
          web_url_policy=$((web_url_policy + 1))
          ;;
        000|5*)
          _url_state="down"
          web_url_down=$((web_url_down + 1))
          ;;
        *)
          _url_state="restricted"
          web_url_restricted=$((web_url_restricted + 1))
          ;;
      esac
      ;;
    *)
      case "${_http_code}" in
        2*|3*)
          _url_state="up"
          web_url_up=$((web_url_up + 1))
          ;;
        401|403|405)
          _url_state="restricted"
          web_url_restricted=$((web_url_restricted + 1))
          ;;
        404)
          _url_state="missing"
          web_url_missing=$((web_url_missing + 1))
          ;;
        000|5*)
          _url_state="down"
          web_url_down=$((web_url_down + 1))
          ;;
        *)
          _url_state="restricted"
          web_url_restricted=$((web_url_restricted + 1))
          ;;
      esac
      ;;
  esac
  web_url_total=$((web_url_total + 1))
  web_url_rows="${web_url_rows}<tr><td class=\"mono\">$(html_escape "${_url}")</td><td>$(html_escape "${_service}")</td><td>$(web_url_status_chip "${_url_state}")</td><td class=\"mono\">${_http_code}</td></tr>"
done < "${web_urls_tmp}"

web_url_probe_note="inventory constrained to approved wg-client URLs; local probes use curl --resolve via ${web_http_probe_ip}:80 and ${web_https_probe_ip}:443; protected endpoints show policy_enforced on expected 401/403/405"

[ -n "${web_url_rows}" ] || web_url_rows="<tr><td class=\"mono\">none</td><td>n/a</td><td>$(web_url_status_chip unknown)</td><td class=\"mono\">000</td></tr>"
web_primary_host_display="$(html_escape "${web_primary_host}")"
web_url_probe_note_display="$(html_escape "${web_url_probe_note}")"

rm -f "${web_nginx_dump}" "${web_urls_tmp}"

render_now_epoch="$(date +%s)"

agent_updated_epoch="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" updated_epoch 0)")"
agent_updated_iso_raw="$(kv_get "${AGENT_SUMMARY_FILE}" updated_iso unknown)"
agent_updated_iso="$(html_escape "${agent_updated_iso_raw}")"
agent_mode_raw="$(kv_get "${AGENT_SUMMARY_FILE}" mode unknown)"
agent_open_tickets="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" open_tickets 0)")"
agent_open_fail="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" open_fail 0)")"
agent_open_warn_or_other="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" open_warn_or_other 0)")"
agent_policy_manual="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" policy_manual 0)")"
agent_policy_assist="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" policy_assist 0)")"
agent_policy_auto_safe="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" policy_auto_safe 0)")"
agent_actions_attempted="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" actions_attempted 0)")"
agent_actions_ok="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" actions_ok 0)")"
agent_actions_failed="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" actions_failed 0)")"
agent_upstream_trust_state_raw="$(kv_get "${AGENT_SUMMARY_FILE}" upstream_trust_state unknown)"
agent_upstream_trust_confidence_pct="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" upstream_trust_confidence_pct 0)")"
agent_upstream_trust_reasons_raw="$(kv_get "${AGENT_SUMMARY_FILE}" upstream_trust_reasons none)"
agent_policy_trust_state_raw="$(kv_get "${AGENT_SUMMARY_FILE}" policy_trust_state unknown)"
agent_policy_execution_gate_raw="$(kv_get "${AGENT_SUMMARY_FILE}" policy_execution_gate unknown)"
agent_policy_trust_reason_raw="$(kv_get "${AGENT_SUMMARY_FILE}" policy_trust_reason none)"
agent_queue_high_risk="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" queue_high_risk 0)")"
agent_queue_medium_risk="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" queue_medium_risk 0)")"
agent_queue_low_risk="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" queue_low_risk 0)")"
agent_queue_trust_verified="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" queue_trust_verified 0)")"
agent_queue_trust_degraded="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" queue_trust_degraded 0)")"
agent_queue_trust_fail_closed="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" queue_trust_fail_closed 0)")"
agent_emergency_open="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" emergency_open 0)")"
agent_emergency_urgent="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" emergency_urgent 0)")"
agent_emergency_breakglass="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" emergency_breakglass 0)")"
agent_approval_required="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" approval_required 0)")"
agent_policy_integrity_holds="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" policy_integrity_holds 0)")"
agent_upstream_trust_holds="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" upstream_trust_holds 0)")"
agent_replay_suppressed="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" replay_suppressed 0)")"
agent_input_refusals="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" input_refusals 0)")"
agent_fast_path_last_run_epoch="$(to_int "$(kv_get "${AGENT_SUMMARY_FILE}" fast_path_last_run_epoch 0)")"
agent_fast_path_last_run_iso_raw="$(kv_get "${AGENT_SUMMARY_FILE}" fast_path_last_run_iso never)"
agent_open_source_raw="$(kv_get "${AGENT_SUMMARY_FILE}" open_tickets_source missing)"
agent_open_source="$(html_escape "${agent_open_source_raw}")"
agent_policy_file_raw="$(kv_get "${AGENT_SUMMARY_FILE}" policy_file "${AGENT_POLICY_FILE}")"
agent_policy_file="$(html_escape "${agent_policy_file_raw}")"
agent_upstream_trust_reasons="$(html_escape "${agent_upstream_trust_reasons_raw}")"
agent_policy_trust_reason="$(html_escape "${agent_policy_trust_reason_raw}")"
agent_fast_path_last_run_iso="$(html_escape "${agent_fast_path_last_run_iso_raw}")"
agent_updated_age_min=-1
if [ "${agent_updated_epoch}" -gt 0 ]; then
  if [ "${render_now_epoch}" -ge "${agent_updated_epoch}" ]; then
    agent_updated_age_min=$(( (render_now_epoch - agent_updated_epoch) / 60 ))
  else
    agent_updated_age_min=0
  fi
fi

agent_default_mode_raw="$(policy_get "${AGENT_POLICY_FILE}" default_mode assist)"
agent_default_mode_raw="$(printf '%s' "${agent_default_mode_raw}" | tr '[:upper:]' '[:lower:]')"
agent_default_mode="$(html_escape "${agent_default_mode_raw}")"
agent_cooldown_sec="$(to_int "$(policy_get "${AGENT_POLICY_FILE}" cooldown_sec 1800)")"
agent_max_auto_actions="$(to_int "$(policy_get "${AGENT_POLICY_FILE}" max_auto_actions_per_run 3)")"
agent_fast_path_min_interval_sec="$(to_int "$(policy_get "${AGENT_POLICY_FILE}" fast_path_min_interval_sec 120)")"
agent_feed_max_age_sec="$(to_int "$(policy_get "${AGENT_POLICY_FILE}" feed_max_age_sec 1200)")"
agent_max_open_tickets="$(to_int "$(policy_get "${AGENT_POLICY_FILE}" max_open_tickets 32)")"

d_pf_states=0
d_mail_queue=0
d_mail_accepted=0
d_suricata_alerts=0
d_svc_fail=0
if [ -n "${prev}" ]; then
  d_pf_states="$(delta_int "${pf_states}" "$(kv_get "${prev}" pf_states 0)")"
  d_mail_queue="$(delta_int "${mail_queue}" "$(kv_get "${prev}" mail_queue 0)")"
  d_mail_accepted="$(delta_int "${mail_accepted}" "$(kv_get "${prev}" mail_accepted 0)")"
  d_suricata_alerts="$(delta_int "${suricata_alerts}" "$(kv_get "${prev}" suricata_alerts 0)")"
  d_svc_fail="$(delta_int "${svc_fail}" "$(kv_get "${prev}" svc_fail 0)")"
fi

svc_health_pct=0
if [ "${svc_total}" -gt 0 ]; then
  svc_health_pct=$(( (svc_ok * 100) / svc_total ))
fi

overall="ok"
if [ "${svc_fail}" -gt 2 ] || [ "${verify_status_raw}" = "FAIL" ] || [ "${cron_fail_count}" -gt 0 ]; then
  overall="critical"
elif [ "${svc_fail}" -gt 0 ] || [ "${cron_warn_count}" -gt 0 ] || [ "${mail_queue}" -gt 25 ]; then
  overall="warn"
fi

mail_health="healthy"
if [ "${mail_queue}" -gt 50 ] || [ "${mail_rejected}" -gt 100 ]; then
  mail_health="degraded"
fi

svc_gate_state="pass"
if [ "${svc_fail}" -gt 2 ]; then
  svc_gate_state="fail"
elif [ "${svc_fail}" -gt 0 ]; then
  svc_gate_state="warn"
fi

verify_gate_state="pass"
if [ "${verify_status_raw}" = "FAIL" ]; then
  verify_gate_state="fail"
elif [ "${verify_status_raw}" != "PASS" ]; then
  verify_gate_state="warn"
fi

cron_gate_state="pass"
if [ "${cron_fail_count}" -gt 0 ]; then
  cron_gate_state="fail"
elif [ "${cron_warn_count}" -gt 0 ]; then
  cron_gate_state="warn"
fi

queue_gate_state="pass"
if [ "${mail_queue}" -gt 50 ]; then
  queue_gate_state="fail"
elif [ "${mail_queue}" -gt 25 ]; then
  queue_gate_state="warn"
fi

gate_critical_count=0
gate_warn_count=0
critical_gate_list=""
warn_gate_list=""
for g in "${svc_gate_state}:service_checks" "${verify_gate_state}:verify_mail_services" "${cron_gate_state}:cron_maintenance" "${queue_gate_state}:mail_queue_depth"; do
  g_state="${g%%:*}"
  g_name="${g#*:}"
  case "${g_state}" in
    fail)
      gate_critical_count=$((gate_critical_count + 1))
      [ -n "${critical_gate_list}" ] && critical_gate_list="${critical_gate_list},${g_name}" || critical_gate_list="${g_name}"
      ;;
    warn)
      gate_warn_count=$((gate_warn_count + 1))
      [ -n "${warn_gate_list}" ] && warn_gate_list="${warn_gate_list},${g_name}" || warn_gate_list="${g_name}"
      ;;
  esac
done

overall_cause_line="all monitored gates are passing"
if [ "${gate_critical_count}" -gt 0 ]; then
  overall_cause_line="critical gates: ${critical_gate_list}"
elif [ "${gate_warn_count}" -gt 0 ]; then
  overall_cause_line="warning gates: ${warn_gate_list}"
fi
overall_cause_html="$(html_escape "${overall_cause_line}")"

svc_fail_list_safe="${svc_fail_list}"
[ -n "${svc_fail_list_safe}" ] || svc_fail_list_safe="none"
svc_non_daemon_list_safe="${svc_non_daemon_list}"
[ -n "${svc_non_daemon_list_safe}" ] || svc_non_daemon_list_safe="none"
cron_fail_jobs_safe="${cron_fail_jobs}"
[ -n "${cron_fail_jobs_safe}" ] || cron_fail_jobs_safe="none"
cron_warn_jobs_safe="${cron_warn_jobs}"
[ -n "${cron_warn_jobs_safe}" ] || cron_warn_jobs_safe="none"
cron_fail_context_safe="${cron_fail_context}"
[ -n "${cron_fail_context_safe}" ] || cron_fail_context_safe="none"
cron_warn_context_safe="${cron_warn_context}"
[ -n "${cron_warn_context_safe}" ] || cron_warn_context_safe="none"
cron_jobs_summary="${cron_fail_jobs_safe}"
if [ "${cron_warn_count}" -gt 0 ]; then
  cron_jobs_summary="${cron_jobs_summary} ; ${cron_warn_jobs_safe}"
fi
svc_fail_list_words="$(printf '%s' "${svc_fail_list_safe}" | tr ',' ' ')"

overall_reason_items=""
case "${svc_gate_state}" in
  fail) overall_reason_items="${overall_reason_items}<li>service checks gate is FAIL: ${svc_fail} daemon checks are failing (${svc_fail_list_safe}), critical threshold is more than 2 failed daemon checks.</li>" ;;
  warn) overall_reason_items="${overall_reason_items}<li>service checks gate is WARN: ${svc_fail} daemon checks are failing (${svc_fail_list_safe}), still below critical threshold.</li>" ;;
esac
if [ "${svc_non_daemon_count}" -gt 0 ]; then
  overall_reason_items="${overall_reason_items}<li>${svc_non_daemon_count} rcctl special-variable toggles are excluded from daemon health scoring (${svc_non_daemon_list_safe}).</li>"
fi
case "${verify_gate_state}" in
  fail) overall_reason_items="${overall_reason_items}<li>verify-mail-services gate is FAIL: latest status is ${verify_status}.</li>" ;;
  warn) overall_reason_items="${overall_reason_items}<li>verify-mail-services gate is WARN: latest status is ${verify_status} (expected PASS).</li>" ;;
esac
case "${cron_gate_state}" in
  fail) overall_reason_items="${overall_reason_items}<li>cron maintenance gate is FAIL: ${cron_fail_count} failed job(s) (${cron_fail_jobs_safe}); context ${cron_fail_context_safe}. impact: maintenance/compliance reporting may be stale until fixed.</li>" ;;
  warn) overall_reason_items="${overall_reason_items}<li>cron maintenance gate is WARN: ${cron_warn_count} warning job(s) (${cron_warn_jobs_safe}); context ${cron_warn_context_safe}.</li>" ;;
esac
case "${queue_gate_state}" in
  fail) overall_reason_items="${overall_reason_items}<li>mail queue gate is FAIL: queue depth ${mail_queue} exceeds critical threshold 50.</li>" ;;
  warn) overall_reason_items="${overall_reason_items}<li>mail queue gate is WARN: queue depth ${mail_queue} exceeds warning threshold 25.</li>" ;;
esac
[ -z "${overall_reason_items}" ] && overall_reason_items="<li>all monitored overall-status gates are currently passing.</li>"

security_score=100
score_pf_deduct=0
score_tcp_deduct=0
score_udp_deduct=0
score_cron_deduct=0
score_verify_deduct=0

pf_security_state="pass"
tcp_security_state="pass"
udp_security_state="pass"
cron_security_state="pass"
verify_security_state="pass"

security_notes=""
if [ "${pf_enabled}" -ne 1 ]; then
  score_pf_deduct=40
  pf_security_state="fail"
  security_notes="${security_notes}<li>pf enforcement unavailable: -40.</li>"
fi
if [ "${public_tcp_count}" -gt 3 ]; then
  score_tcp_deduct=20
  tcp_security_state="warn"
  security_notes="${security_notes}<li>public tcp exposure exceeds baseline (3): ${public_tcp_count}: -20.</li>"
fi
if [ "${public_udp_count}" -gt 2 ]; then
  score_udp_deduct=10
  udp_security_state="warn"
  security_notes="${security_notes}<li>public udp exposure exceeds baseline (2): ${public_udp_count}: -10.</li>"
fi
if [ "${cron_fail_count}" -ne 0 ]; then
  score_cron_deduct=15
  cron_security_state="warn"
  security_notes="${security_notes}<li>maintenance evidence pipeline has fail(s): -15.</li>"
elif [ "${cron_warn_count}" -ne 0 ]; then
  cron_security_state="warn"
fi
if [ "${verify_status_raw}" != "PASS" ]; then
  score_verify_deduct=15
  if [ "${verify_status_raw}" = "FAIL" ]; then
    verify_security_state="fail"
  else
    verify_security_state="warn"
  fi
  security_notes="${security_notes}<li>verify-mail-services not PASS (${verify_status}): -15.</li>"
fi

score_total_deduct=$((score_pf_deduct + score_tcp_deduct + score_udp_deduct + score_cron_deduct + score_verify_deduct))
security_score=$((100 - score_total_deduct))
[ "${security_score}" -ge 0 ] || security_score=0
[ -n "${security_notes}" ] || security_notes="<li>no security-score deductions currently applied.</li>"

incidents_24h=$((cron_fail_count + cron_warn_count))

suricata_status_lc="$(printf '%s' "${suricata_status_raw}" | tr '[:upper:]' '[:lower:]')"

mail_ops_state="ok"
if [ "${verify_status_raw}" = "FAIL" ] || [ "${mailstats_age_min}" -gt 60 ] || [ "${mail_trend_age_min}" -gt 90 ]; then
  mail_ops_state="fail"
elif [ "${verify_status_raw}" != "PASS" ] || [ "${mailstats_age_min}" -gt 20 ] || [ "${mail_trend_age_min}" -gt 45 ]; then
  mail_ops_state="warn"
fi

sbom_ops_state="ok"
if [ "${sbom_daily_status_raw}" = "FAIL" ] || [ "${sbom_daily_age_min}" -lt 0 ] || [ "${sbom_daily_age_min}" -gt 1560 ]; then
  sbom_ops_state="fail"
elif [ "${sbom_daily_status_raw}" != "PASS" ] || [ "${sbom_weekly_status_raw}" != "PASS" ] || [ "${sbom_weekly_age_min}" -gt 11520 ]; then
  sbom_ops_state="warn"
fi

suricata_ops_state="ok"
if [ "${suricata_status_lc}" != "running" ] && [ "${suricata_status_lc}" != "enabled" ]; then
  suricata_ops_state="fail"
elif [ "${suricata_mode_block_cron}" -ne 1 ]; then
  suricata_ops_state="fail"
elif [ "${suricata_age_min}" -gt 20 ] || [ "${suricata_trend_age_min}" -gt 45 ]; then
  suricata_ops_state="warn"
fi

pf_ops_state="ok"
if [ "${pf_enabled}" -ne 1 ]; then
  pf_ops_state="fail"
elif [ "${suricata_mode_block_cron}" -ne 1 ]; then
  pf_ops_state="fail"
elif [ "${suricata_eve2pf_candidates}" -gt 0 ] && [ "${table_suricata_block}" -eq 0 ]; then
  pf_ops_state="fail"
elif [ "${suricata_eve2pf_log_age_min}" -lt 0 ] || [ "${suricata_eve2pf_log_age_min}" -gt 20 ]; then
  pf_ops_state="warn"
elif [ "${suricata_eve2pf_candidates}" -gt 0 ] && [ "${table_suricata_block}" -lt "${suricata_eve2pf_candidates}" ]; then
  pf_ops_state="warn"
fi

patch_ops_state="ok"
if [ "${cron_weekly_maintenance_4am}" -ne 1 ] || [ "${cron_daily_patch_scan}" -ne 1 ] || [ "${cron_regression_gate}" -ne 1 ]; then
  patch_ops_state="fail"
elif [ "${weekly_maintenance_pending}" -eq 1 ] || [ "${weekly_maintenance_log_age_min}" -lt 0 ] || [ "${weekly_maintenance_log_age_min}" -gt 10080 ]; then
  patch_ops_state="warn"
elif [ "${maint_last_regression_pass}" -ne 1 ]; then
  patch_ops_state="warn"
fi

reporting_ops_state="ok"
if [ "${cron_mailto_ops}" -ne 1 ]; then
  reporting_ops_state="fail"
elif [ "${cron_html_report_count}" -lt 1 ] || [ "${cron_reports_24h}" -lt 1 ] || [ "${cron_report_latest_age_min}" -lt 0 ] || [ "${cron_report_latest_age_min}" -gt 720 ]; then
  reporting_ops_state="warn"
fi

report_trust_ops_state="${report_trust_state_raw}"
case "${report_trust_ops_state}" in
  ok|warn|fail) ;;
  *) report_trust_ops_state="warn" ;;
esac

lifecycle_syspatch_state="ok"
if [ "${syspatch_check_status_raw}" = "error" ]; then
  lifecycle_syspatch_state="fail"
elif [ "${syspatch_pending_count}" -gt 0 ]; then
  lifecycle_syspatch_state="warn"
elif [ "${syspatch_data_source_raw}" = "maint_plan" ] && \
  { [ "${maint_plan_status_raw}" != "PASS" ] || [ "${maint_plan_age_min}" -lt 0 ] || [ "${maint_plan_age_min}" -gt 1560 ]; }; then
  lifecycle_syspatch_state="fail"
fi

lifecycle_pkg_state="ok"
if [ "${pkg_upgrade_last_run_age_min}" -lt 0 ] || [ "${pkg_upgrade_last_run_age_min}" -gt 10080 ]; then
  lifecycle_pkg_state="fail"
elif [ "${pkg_upgrade_last_post_verify_status_raw}" = "fail" ]; then
  lifecycle_pkg_state="fail"
elif [ "${pkg_add_u_recent}" -ne 1 ] || [ "${pkg_upgrade_last_post_verify_status_raw}" = "no_flag" ] || \
  [ "${pkg_upgrade_last_post_verify_status_raw}" = "none" ] || [ "${pkg_snapshot_age_min}" -lt 0 ] || [ "${pkg_snapshot_age_min}" -gt 1560 ]; then
  lifecycle_pkg_state="warn"
fi

lifecycle_cve_state="ok"
if [ "${sbom_report_age_min}" -lt 0 ] || [ "${sbom_report_age_min}" -gt 1560 ]; then
  lifecycle_cve_state="fail"
elif [ "${sbom_vuln_total}" -gt 0 ]; then
  lifecycle_cve_state="fail"
elif [ "${cve_mapping_supported}" -ne 1 ] || [ "${sbom_exceptions_expired}" -gt 0 ]; then
  lifecycle_cve_state="warn"
fi

lifecycle_sdlc_state="${lifecycle_gap_state_raw}"
if [ -z "${lifecycle_sdlc_state}" ]; then
  lifecycle_sdlc_state="unknown"
fi

lifecycle_syspatch_chip="$(status_chip "${lifecycle_syspatch_state}")"
lifecycle_pkg_chip="$(status_chip "${lifecycle_pkg_state}")"
lifecycle_cve_chip="$(status_chip "${lifecycle_cve_state}")"
lifecycle_sdlc_chip="$(status_chip "${lifecycle_sdlc_state}")"

syspatch_pending_display="${syspatch_pending_list}"
if [ "${syspatch_pending_count}" -eq 0 ]; then
  syspatch_pending_display="none"
fi
syspatch_pending_display_h="$(html_escape "${syspatch_pending_display}")"
syspatch_evidence_age_display="${maint_plan_age_min}m"
if [ "${syspatch_data_source_raw}" = "live_check" ]; then
  syspatch_evidence_age_display="snapshot-time live"
fi
syspatch_check_summary="source=${syspatch_data_source}; check=${syspatch_check_status}; rc=${syspatch_check_rc}"

pkg_last_run_display="${pkg_upgrade_last_run_ts_raw}"
[ -n "${pkg_last_run_display}" ] || pkg_last_run_display="none"
pkg_last_apply_display="${pkg_upgrade_last_apply_ts_raw}"
[ -n "${pkg_last_apply_display}" ] || pkg_last_apply_display="none"
pkg_last_post_display="${pkg_upgrade_last_post_verify_ts_raw}"
[ -n "${pkg_last_post_display}" ] || pkg_last_post_display="none"
pkg_last_run_display_h="$(html_escape "${pkg_last_run_display}")"
pkg_last_apply_display_h="$(html_escape "${pkg_last_apply_display}")"
pkg_last_post_display_h="$(html_escape "${pkg_last_post_display}")"

cve_findings_display="${cve_associated_findings}"
if [ "${cve_associated_findings}" -lt 0 ]; then
  cve_findings_display="unmapped"
fi

mail_ops_chip="$(status_chip "${mail_ops_state}")"
sbom_ops_chip="$(status_chip "${sbom_ops_state}")"
suricata_ops_chip="$(status_chip "${suricata_ops_state}")"
pf_ops_chip="$(status_chip "${pf_ops_state}")"
patch_ops_chip="$(status_chip "${patch_ops_state}")"
reporting_ops_chip="$(status_chip "${reporting_ops_state}")"
report_trust_ops_chip="$(status_chip "${report_trust_ops_state}")"

ops_control_fail=0
ops_control_warn=0
for ops_state in "${mail_ops_state}" "${sbom_ops_state}" "${suricata_ops_state}" "${pf_ops_state}" "${patch_ops_state}" "${reporting_ops_state}" "${report_trust_ops_state}"; do
  case "${ops_state}" in
    fail) ops_control_fail=$((ops_control_fail + 1)) ;;
    warn) ops_control_warn=$((ops_control_warn + 1)) ;;
  esac
done

agent_queue_rows=""
agent_queue_rows_short=""
agent_queue_count=0
agent_queue_fail_count=0
agent_queue_warn_count=0
agent_queue_policy_manual=0
agent_queue_policy_assist=0
agent_queue_policy_auto_safe=0
agent_queue_state_executed_ok=0
agent_queue_state_executed_fail=0
agent_queue_state_assist_review=0
agent_queue_state_manual_review=0
agent_queue_state_deferred=0
agent_queue_state_requires_approval=0
agent_queue_state_other=0
agent_queue_oldest_age_min=0
agent_queue_oldest_ticket="none"
agent_queue_oldest_control="none"
agent_queue_risk_top_score=0
agent_queue_top_trust="none"
agent_queue_top_emergency="none"

if [ -r "${AGENT_QUEUE_TSV}" ] && [ -s "${AGENT_QUEUE_TSV}" ]; then
  while IFS="$(printf '\t')" read -r q_ticket q_control q_sev q_opened q_age q_policy q_state q_last_exec q_runbook q_exec q_evidence q_risk q_risk_level q_confidence q_trust q_emergency q_approval q_breakglass q_score_factors; do
    [ "${q_ticket}" = "ticket_id" ] && continue
    [ -n "${q_ticket}" ] || continue

    q_age_i="$(to_int "${q_age}")"
    q_risk_i="$(to_int "${q_risk}")"
    [ "${q_age_i}" -gt "${agent_queue_oldest_age_min}" ] && {
      agent_queue_oldest_age_min="${q_age_i}"
      agent_queue_oldest_ticket="${q_ticket}"
      agent_queue_oldest_control="${q_control}"
    }
    [ "${q_risk_i}" -gt "${agent_queue_risk_top_score}" ] && agent_queue_risk_top_score="${q_risk_i}"
    [ "${agent_queue_count}" -eq 0 ] && {
      agent_queue_top_trust="${q_trust}"
      agent_queue_top_emergency="${q_emergency}"
    }

    case "$(printf '%s' "${q_sev}" | tr '[:upper:]' '[:lower:]')" in
      fail|critical) agent_queue_fail_count=$((agent_queue_fail_count + 1)) ;;
      *) agent_queue_warn_count=$((agent_queue_warn_count + 1)) ;;
    esac

    case "$(printf '%s' "${q_policy}" | tr '[:upper:]' '[:lower:]')" in
      manual) agent_queue_policy_manual=$((agent_queue_policy_manual + 1)) ;;
      auto_safe) agent_queue_policy_auto_safe=$((agent_queue_policy_auto_safe + 1)) ;;
      *) agent_queue_policy_assist=$((agent_queue_policy_assist + 1)) ;;
    esac

    case "${q_state}" in
      executed_ok) agent_queue_state_executed_ok=$((agent_queue_state_executed_ok + 1)) ;;
      executed_fail) agent_queue_state_executed_fail=$((agent_queue_state_executed_fail + 1)) ;;
      assist_review_required) agent_queue_state_assist_review=$((agent_queue_state_assist_review + 1)) ;;
      manual_review_required) agent_queue_state_manual_review=$((agent_queue_state_manual_review + 1)) ;;
      deferred_cooldown|deferred_max_per_run|replay_suppressed) agent_queue_state_deferred=$((agent_queue_state_deferred + 1)) ;;
      requires_human_approval|policy_integrity_review_required|upstream_trust_review_required) agent_queue_state_requires_approval=$((agent_queue_state_requires_approval + 1)) ;;
      *) agent_queue_state_other=$((agent_queue_state_other + 1)) ;;
    esac

    agent_queue_count=$((agent_queue_count + 1))
    q_ticket_h="$(html_escape "${q_ticket}")"
    q_control_h="$(html_escape "${q_control}")"
    q_opened_h="$(html_escape "${q_opened}")"
    q_last_exec_h="$(html_escape "${q_last_exec}")"
    q_runbook_h="$(html_escape "${q_runbook}")"
    q_exec_h="$(html_escape "${q_exec}")"
    q_evidence_h="$(html_escape "${q_evidence}")"
    q_breakglass_h="$(html_escape "${q_breakglass}")"
    q_score_h="$(html_escape "${q_score_factors}")"

    agent_queue_rows="${agent_queue_rows}<tr><td class=\"mono\">${q_ticket_h}</td><td class=\"mono\">${q_control_h}</td><td>$(status_chip "${q_sev}")</td><td>$(risk_level_chip "${q_risk_level}") <span class=\"mono\">${q_risk_i}</span></td><td>$(trust_state_chip "${q_trust}") <span class=\"mono\">${q_confidence}%</span></td><td>$(emergency_state_chip "${q_emergency}")</td><td>$(approval_gate_chip "${q_approval}")</td><td>$(policy_mode_chip "${q_policy}")</td><td>$(action_state_chip "${q_state}")</td><td class=\"mono\">${q_opened_h}</td><td>${q_age_i}m</td><td class=\"mono\">${q_last_exec_h}</td><td>${q_runbook_h}</td><td class=\"mono\">${q_exec_h}</td><td class=\"mono\">${q_breakglass_h}</td><td class=\"mono\">${q_evidence_h}</td><td class=\"mono\">${q_score_h}</td></tr>"

    if [ "${agent_queue_count}" -le 5 ]; then
      agent_queue_rows_short="${agent_queue_rows_short}<tr><td class=\"mono\">${q_control_h}</td><td>$(risk_level_chip "${q_risk_level}") <span class=\"mono\">${q_risk_i}</span></td><td>$(trust_state_chip "${q_trust}") <span class=\"mono\">${q_confidence}%</span></td><td>$(emergency_state_chip "${q_emergency}")</td><td>$(approval_gate_chip "${q_approval}")</td><td>$(action_state_chip "${q_state}")</td><td>${q_age_i}m</td><td>${q_runbook_h}</td></tr>"
    fi
  done < "${AGENT_QUEUE_TSV}"
fi

[ -n "${agent_queue_rows}" ] || agent_queue_rows="<tr><td colspan=\"17\">no queued phase-14 tickets found</td></tr>"
[ -n "${agent_queue_rows_short}" ] || agent_queue_rows_short="<tr><td colspan=\"8\">no queued phase-14 tickets found</td></tr>"

agent_emergency_rows=""
if [ -r "${AGENT_EMERGENCY_TSV}" ] && [ -s "${AGENT_EMERGENCY_TSV}" ]; then
  while IFS="$(printf '\t')" read -r e_ticket e_control e_sev e_risk e_conf e_state e_gate e_trust e_opened e_age e_breakglass e_evidence; do
    [ "${e_ticket}" = "ticket_id" ] && continue
    [ -n "${e_ticket}" ] || continue
    agent_emergency_rows="${agent_emergency_rows}<tr><td class=\"mono\">$(html_escape "${e_ticket}")</td><td class=\"mono\">$(html_escape "${e_control}")</td><td>$(status_chip "${e_sev}")</td><td>$(risk_level_chip "$( [ "$(to_int "${e_risk}")" -ge 60 ] && print -- high || print -- medium )") <span class=\"mono\">$(to_int "${e_risk}")</span></td><td>$(trust_state_chip "${e_trust}") <span class=\"mono\">$(to_int "${e_conf}")%</span></td><td>$(emergency_state_chip "${e_state}")</td><td>$(approval_gate_chip "${e_gate}")</td><td class=\"mono\">$(html_escape "${e_opened}")</td><td>$(to_int "${e_age}")m</td><td class=\"mono\">$(html_escape "${e_breakglass}")</td><td class=\"mono\">$(html_escape "${e_evidence}")</td></tr>"
  done < "${AGENT_EMERGENCY_TSV}"
fi
[ -n "${agent_emergency_rows}" ] || agent_emergency_rows="<tr><td colspan=\"11\">no emergency or approval-gated queue entries</td></tr>"

agent_refusal_rows=""
if [ -r "${AGENT_REFUSAL_TSV}" ] && [ -s "${AGENT_REFUSAL_TSV}" ]; then
  while IFS="$(printf '\t')" read -r r_epoch r_iso r_ticket r_control r_reason r_detail r_evidence; do
    [ "${r_epoch}" = "seen_epoch" ] && continue
    [ -n "${r_epoch}" ] || continue
    agent_refusal_rows="${agent_refusal_rows}<tr><td class=\"mono\">$(html_escape "${r_iso}")</td><td class=\"mono\">$(html_escape "${r_ticket}")</td><td class=\"mono\">$(html_escape "${r_control}")</td><td>$(trust_state_chip fail_closed) <span class=\"mono\">$(html_escape "${r_reason}")</span></td><td class=\"mono\">$(html_escape "${r_detail}")</td><td class=\"mono\">$(html_escape "${r_evidence}")</td></tr>"
  done < "${AGENT_REFUSAL_TSV}"
fi
[ -n "${agent_refusal_rows}" ] || agent_refusal_rows="<tr><td colspan=\"6\">no suspect or refused inputs recorded</td></tr>"

agent_action_total=0
agent_action_24h=0
agent_action_ok_24h=0
agent_action_fail_24h=0
agent_action_last_iso="never"
agent_action_last_state="none"
agent_action_last_ticket="none"
agent_action_rows=""
agent_action_rows_short=""
agent_action_sort_tmp=""

if [ -r "${AGENT_ACTION_LOG}" ] && [ -s "${AGENT_ACTION_LOG}" ]; then
  read agent_action_total agent_action_24h agent_action_ok_24h agent_action_fail_24h <<EOF_AGENT_ACTION
$(awk -F'\t' -v cutoff="$((render_now_epoch - 86400))" '
  NF >= 9 {
    total++
    if (($1 + 0) >= cutoff) {
      win++
      if ($6 == "executed_ok") ok++
      else if ($6 == "executed_fail") fail++
    }
  }
  END { printf "%d %d %d %d\n", total+0, win+0, ok+0, fail+0 }
' "${AGENT_ACTION_LOG}" 2>/dev/null)
EOF_AGENT_ACTION

  agent_action_sort_tmp="$(mktemp /tmp/obsd-monitor-agent-action.XXXXXX)"
  sort -nr -k1,1 "${AGENT_ACTION_LOG}" > "${agent_action_sort_tmp}" 2>/dev/null || cp "${AGENT_ACTION_LOG}" "${agent_action_sort_tmp}"
  agent_action_row_idx=0
  while IFS="$(printf '\t')" read -r a_epoch a_iso a_ticket a_control a_policy a_state a_rc a_duration a_log_path; do
    [ -n "${a_epoch}" ] || continue
    agent_action_row_idx=$((agent_action_row_idx + 1))
    [ "${agent_action_row_idx}" -eq 1 ] && {
      agent_action_last_iso="${a_iso}"
      agent_action_last_state="${a_state}"
      agent_action_last_ticket="${a_ticket}"
    }
    [ "${agent_action_row_idx}" -le 25 ] || continue

    a_rc_i="$(to_int "${a_rc}")"
    a_duration_i="$(to_int "${a_duration}")"
    a_iso_h="$(html_escape "${a_iso}")"
    a_ticket_h="$(html_escape "${a_ticket}")"
    a_control_h="$(html_escape "${a_control}")"
    a_log_h="$(html_escape "${a_log_path}")"

    agent_action_rows="${agent_action_rows}<tr><td class=\"mono\">${a_iso_h}</td><td class=\"mono\">${a_ticket_h}</td><td class=\"mono\">${a_control_h}</td><td>$(policy_mode_chip "${a_policy}")</td><td>$(action_state_chip "${a_state}")</td><td>${a_rc_i}</td><td>${a_duration_i}s</td><td class=\"mono\">${a_log_h}</td></tr>"

    if [ "${agent_action_row_idx}" -le 5 ]; then
      agent_action_rows_short="${agent_action_rows_short}<tr><td class=\"mono\">${a_iso_h}</td><td class=\"mono\">${a_control_h}</td><td>$(action_state_chip "${a_state}")</td><td>${a_rc_i}</td><td>${a_duration_i}s</td></tr>"
    fi
  done < "${agent_action_sort_tmp}"
  rm -f "${agent_action_sort_tmp}"
fi

[ -n "${agent_action_rows}" ] || agent_action_rows="<tr><td colspan=\"8\">no phase-14 execution actions logged yet</td></tr>"
[ -n "${agent_action_rows_short}" ] || agent_action_rows_short="<tr><td colspan=\"5\">no phase-14 execution actions logged yet</td></tr>"

agent_action_log_present=0
[ -f "${AGENT_ACTION_LOG}" ] && agent_action_log_present=1

agent_policy_rows=""
for ckey in ops-mail-operational ops-sbom-lifecycle ops-suricata-active-block ops-pf-reactive-enforcement ops-patch-weekly-and-daily-scan ops-change-catalog-email ops-report-trust-governance; do
  cmode_raw="$(policy_get "${AGENT_POLICY_FILE}" "${ckey}" "${agent_default_mode_raw}")"
  cmode_raw="$(printf '%s' "${cmode_raw}" | tr '[:upper:]' '[:lower:]')"
  case "${ckey}" in
    ops-mail-operational) cobjective="mail service remains operational and maillog telemetry is current" ;;
    ops-sbom-lifecycle) cobjective="daily and weekly sbom lifecycle checks stay fresh and passing" ;;
    ops-suricata-active-block) cobjective="suricata remains in active block mode with fresh reporting" ;;
    ops-pf-reactive-enforcement) cobjective="pf remains active and synchronized with suricata tables" ;;
    ops-patch-weekly-and-daily-scan) cobjective="daily patch scan and weekly patch cycle with regression gate remain enforced" ;;
    ops-change-catalog-email) cobjective="maintenance and change reporting remains cataloged and emailed to ops" ;;
    ops-report-trust-governance) cobjective="report trust stays semantically accurate and high-risk daemon/config drift remains visible" ;;
    *) cobjective="custom phase-14 control objective" ;;
  esac
  agent_policy_rows="${agent_policy_rows}<tr><td class=\"mono\">$(html_escape "${ckey}")</td><td>$(policy_mode_chip "${cmode_raw}")</td><td>${cobjective}</td></tr>"
done
[ -n "${agent_policy_rows}" ] || agent_policy_rows="<tr><td colspan=\"3\">no control policy entries found</td></tr>"

agent_behavior_state="ok"
if [ "${agent_updated_age_min}" -lt 0 ] || [ "${agent_updated_age_min}" -gt 45 ]; then
  agent_behavior_state="fail"
elif [ "${agent_policy_trust_state_raw}" = "tampered" ] || [ "${agent_policy_trust_state_raw}" = "downgraded" ] || [ "${agent_policy_trust_state_raw}" = "invalid" ]; then
  agent_behavior_state="fail"
elif [ "${agent_upstream_trust_state_raw}" = "fail_closed" ] || [ "${agent_emergency_breakglass}" -gt 0 ] || [ "${agent_actions_failed}" -gt 0 ] || [ "${agent_queue_fail_count}" -gt 0 ]; then
  agent_behavior_state="fail"
elif [ "${agent_upstream_trust_state_raw}" = "degraded" ] || [ "${agent_input_refusals}" -gt 0 ] || [ "${agent_emergency_open}" -gt 0 ] || [ "${agent_queue_count}" -gt 0 ]; then
  agent_behavior_state="warn"
elif [ "${agent_action_fail_24h}" -gt 0 ] && [ "${agent_action_last_state}" = "executed_fail" ]; then
  agent_behavior_state="warn"
fi
agent_behavior_chip="$(status_chip "${agent_behavior_state}")"

agent_queue_state="ok"
if [ "${agent_queue_fail_count}" -gt 0 ] || [ "${agent_emergency_breakglass}" -gt 0 ]; then
  agent_queue_state="fail"
elif [ "${agent_queue_count}" -gt 0 ] || [ "${agent_emergency_open}" -gt 0 ]; then
  agent_queue_state="warn"
fi
agent_queue_chip="$(status_chip "${agent_queue_state}")"

agent_action_state_summary="ok"
if [ "${agent_action_fail_24h}" -gt 0 ] && [ "${agent_action_last_state}" = "executed_fail" ]; then
  agent_action_state_summary="fail"
elif [ "${agent_action_fail_24h}" -gt 0 ]; then
  agent_action_state_summary="warn"
elif [ "${agent_action_24h}" -gt 0 ] && [ "${agent_action_ok_24h}" -lt "${agent_action_24h}" ]; then
  agent_action_state_summary="warn"
fi
agent_action_summary_chip="$(status_chip "${agent_action_state_summary}")"
agent_mode_chip="$(agent_run_mode_chip "${agent_mode_raw}")"
agent_mode_desc="unknown mode"
case "$(printf '%s' "${agent_mode_raw}" | tr '[:upper:]' '[:lower:]')" in
  run) agent_mode_desc="scheduled control-loop execution mode" ;;
  analyze) agent_mode_desc="read-only analysis mode" ;;
  report) agent_mode_desc="report generation mode" ;;
esac
agent_mode_desc_h="$(html_escape "${agent_mode_desc}")"

agent_summary_queue_delta=$((agent_queue_count - agent_open_tickets))
agent_summary_queue_delta_abs="${agent_summary_queue_delta#-}"
agent_summary_consistency="ok"
if [ "${agent_summary_queue_delta_abs}" -gt 0 ]; then
  agent_summary_consistency="warn"
fi
agent_summary_consistency_chip="$(status_chip "${agent_summary_consistency}")"
agent_upstream_trust_chip="$(trust_state_chip "${agent_upstream_trust_state_raw}")"
agent_policy_trust_chip="$(trust_state_chip "${agent_policy_trust_state_raw}")"
agent_policy_execution_chip="$(approval_gate_chip "${agent_policy_execution_gate_raw}")"
agent_top_emergency_chip="$(emergency_state_chip "${agent_queue_top_emergency}")"

agent_queue_tsv_path="$(html_escape "${AGENT_QUEUE_TSV}")"
agent_queue_json_path="$(html_escape "${AGENT_QUEUE_JSON}")"
agent_emergency_tsv_path="$(html_escape "${AGENT_EMERGENCY_TSV}")"
agent_emergency_json_path="$(html_escape "${AGENT_EMERGENCY_JSON}")"
agent_refusal_tsv_path="$(html_escape "${AGENT_REFUSAL_TSV}")"
agent_summary_kv_path="$(html_escape "${AGENT_SUMMARY_FILE}")"
agent_summary_json_path="$(html_escape "${AGENT_SUMMARY_JSON}")"
agent_last_report_path="$(html_escape "${AGENT_LAST_REPORT_TXT}")"
agent_action_log_path="$(html_escape "${AGENT_ACTION_LOG}")"
agent_policy_path="$(html_escape "${AGENT_POLICY_FILE}")"
agent_policy_trust_kv_path="$(html_escape "${AGENT_POLICY_TRUST_KV}")"
agent_policy_trust_json_path="$(html_escape "${AGENT_POLICY_TRUST_JSON}")"
agent_oldest_ticket_h="$(html_escape "${agent_queue_oldest_ticket}")"
agent_oldest_control_h="$(html_escape "${agent_queue_oldest_control}")"
agent_last_action_iso_h="$(html_escape "${agent_action_last_iso}")"
agent_last_action_state_h="$(html_escape "${agent_action_last_state}")"
agent_last_action_ticket_h="$(html_escape "${agent_action_last_ticket}")"

agent_changes=""
agent_changes="${agent_changes}<li>phase-14 summary updated ${agent_updated_iso} (${agent_updated_age_min}m ago), mode ${agent_mode_raw}, behavior ${agent_behavior_state}.</li>"
agent_changes="${agent_changes}<li>queue now ${agent_queue_count} open tickets (fail=${agent_queue_fail_count}, warn/other=${agent_queue_warn_count}); top risk score ${agent_queue_risk_top_score}, oldest ${agent_oldest_ticket_h} (${agent_oldest_control_h}) open ${agent_queue_oldest_age_min}m.</li>"
agent_changes="${agent_changes}<li>upstream trust ${agent_upstream_trust_state_raw} (${agent_upstream_trust_confidence_pct}% confidence) with reasons ${agent_upstream_trust_reasons}; policy trust ${agent_policy_trust_state_raw} via ${agent_policy_execution_gate_raw}.</li>"
agent_changes="${agent_changes}<li>emergency queue open=${agent_emergency_open}, urgent=${agent_emergency_urgent}, breakglass_review=${agent_emergency_breakglass}, approval_required=${agent_approval_required}; refused inputs=${agent_input_refusals}.</li>"
agent_changes="${agent_changes}<li>policy distribution in queue manual=${agent_queue_policy_manual}, assist=${agent_queue_policy_assist}, auto_safe=${agent_queue_policy_auto_safe}; summary source reports manual=${agent_policy_manual}, assist=${agent_policy_assist}, auto_safe=${agent_policy_auto_safe}.</li>"
agent_changes="${agent_changes}<li>action states in queue executed_ok=${agent_queue_state_executed_ok}, executed_fail=${agent_queue_state_executed_fail}, assist_review_required=${agent_queue_state_assist_review}, manual_review_required=${agent_queue_state_manual_review}, approval_or_hold=${agent_queue_state_requires_approval}, deferred=${agent_queue_state_deferred}, other=${agent_queue_state_other}.</li>"
agent_changes="${agent_changes}<li>action log (24h): total=${agent_action_24h}, executed_ok=${agent_action_ok_24h}, executed_fail=${agent_action_fail_24h}; latest action ${agent_last_action_iso_h} state ${agent_last_action_state_h} ticket ${agent_last_action_ticket_h}; replay_suppressed=${agent_replay_suppressed}.</li>"
agent_changes="${agent_changes}<li>report-trust governance ${report_trust_state}; false_green=${report_trust_false_green_count}; advisory=${report_trust_advisory_count}; reasons=${report_trust_reasons}.</li>"

agent_changes_page_note=""
if [ "${agent_summary_queue_delta_abs}" -gt 0 ]; then
  agent_changes_page_note="summary/open-ticket count mismatch detected (queue=${agent_queue_count}, summary=${agent_open_tickets}); run <span class=\"mono\">doas -n /usr/local/sbin/ops-agent-run.ksh --run</span> to resync artifacts."
else
  agent_changes_page_note="phase-14 queue and summary counters are consistent."
fi

agent_action_expectation_note=""
if [ "${agent_policy_trust_state_raw}" = "tampered" ] || [ "${agent_policy_trust_state_raw}" = "downgraded" ] || [ "${agent_policy_trust_state_raw}" = "invalid" ]; then
  agent_action_expectation_note="policy trust is not acceptable for unattended execution; review <span class=\"mono\">${agent_policy_trust_kv_path}</span>, repair the policy, then re-approve it before expecting auto-safe execution."
elif [ "${agent_upstream_trust_state_raw}" = "fail_closed" ]; then
  agent_action_expectation_note="upstream monitor trust is fail-closed, so PHASE-14 is intentionally queueing without execution until the ticket feed is trustworthy again."
elif [ "${agent_queue_policy_auto_safe}" -eq 0 ] && [ "${agent_action_total}" -eq 0 ]; then
  agent_action_expectation_note="no execution actions are expected while controls remain in <span class=\"mono\">documented operator review</span>; this is normal."
elif [ "${agent_queue_policy_auto_safe}" -gt 0 ] && [ "${agent_action_log_present}" -eq 0 ]; then
  agent_action_expectation_note="one or more controls are <span class=\"mono\">auto_safe</span> but no action log file exists yet; run <span class=\"mono\">doas -n /usr/local/sbin/ops-agent-run.ksh --run</span> and verify <span class=\"mono\">${agent_action_log_path}</span>."
elif [ "${agent_action_total}" -gt 0 ]; then
  agent_action_expectation_note="execution logs are present; newest rows appear below for audit and remediation tracking."
else
  agent_action_expectation_note="action execution remains policy-gated; review policy map and queue states before enabling auto-safe controls."
fi

active_issue_rows=""
if [ "${svc_fail}" -gt 0 ]; then
  active_issue_rows="${active_issue_rows}<tr><td>daemon health failures</td><td>$(status_chip "${svc_gate_state}")</td><td>${svc_fail} failed daemon checks (${svc_fail_list_safe})</td><td><span class=\"mono\">rcctl check ${svc_fail_list_safe//,/ }</span>; review <span class=\"mono\">/var/log/messages</span>; see <span class=\"mono\">host.html</span> for rollup</td></tr>"
fi
if [ "${cron_fail_count}" -gt 0 ]; then
  active_issue_rows="${active_issue_rows}<tr><td>maintenance cron failures</td><td>$(status_chip fail)</td><td>${cron_fail_count} failed jobs (${cron_fail_jobs_safe}); ${cron_fail_context_safe}</td><td>open log path from context; rerun failed command from <span class=\"mono\">${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}/cron-*.json</span>; reference <span class=\"mono\">docs/ops/weekly-ops-cron-reporting.md</span></td></tr>"
fi
if [ "${cron_warn_count}" -gt 0 ]; then
  active_issue_rows="${active_issue_rows}<tr><td>maintenance cron warnings</td><td>$(status_chip warn)</td><td>${cron_warn_count} warning jobs (${cron_warn_jobs_safe}); ${cron_warn_context_safe}</td><td>review report json and related logs; rerun command if warning persists for two runs</td></tr>"
fi
if [ "${verify_status_raw}" != "PASS" ]; then
  active_issue_rows="${active_issue_rows}<tr><td>verify-mail-services not PASS</td><td>$(status_chip "${verify_gate_state}")</td><td>verify status ${verify_status}</td><td><span class=\"mono\">cat ${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}/verify-mail-services.json</span>; run verify playbook; reference <span class=\"mono\">mail.html</span></td></tr>"
fi
if [ "${mail_queue}" -gt 25 ]; then
  active_issue_rows="${active_issue_rows}<tr><td>mail queue depth elevated</td><td>$(status_chip "${queue_gate_state}")</td><td>active queue ${mail_queue}</td><td><span class=\"mono\">postqueue -p</span>; inspect <span class=\"mono\">/var/log/maillog</span>; clear stuck destinations</td></tr>"
fi
if [ "${pf_enabled}" -ne 1 ]; then
  active_issue_rows="${active_issue_rows}<tr><td>packet filter disabled</td><td>$(status_chip fail)</td><td>pf_enabled=${pf_enabled}</td><td><span class=\"mono\">pfctl -s info</span>; verify boot policy; restore pf service state per firewall runbook</td></tr>"
fi
if [ "${public_tcp_count}" -gt 3 ]; then
  active_issue_rows="${active_issue_rows}<tr><td>tcp exposure above baseline</td><td>$(status_chip warn)</td><td>${public_tcp_count} public tcp listeners (${public_tcp_list})</td><td>compare with policy ports <span class=\"mono\">${verify_public_ports}</span>; inspect nginx/pf listener intent</td></tr>"
fi
if [ "${public_udp_count}" -gt 2 ]; then
  active_issue_rows="${active_issue_rows}<tr><td>udp exposure above baseline</td><td>$(status_chip warn)</td><td>${public_udp_count} public udp listeners (${public_udp_list})</td><td>compare with policy ports <span class=\"mono\">${verify_public_ports}</span>; inspect wg/unbound exposure</td></tr>"
fi
if [ "${backup_mailstack_age_min}" -lt 0 ] || [ "${backup_mysql_age_min}" -lt 0 ]; then
  active_issue_rows="${active_issue_rows}<tr><td>backup freshness unknown</td><td>$(status_chip warn)</td><td>mailstack age=${backup_mailstack_age_min}, mysql age=${backup_mysql_age_min}</td><td>verify backup paths under <span class=\"mono\">/var/backups/openbsd-self-hosting</span>; run backup job manually and confirm timestamp advance</td></tr>"
fi
if [ "${sbom_ops_state}" != "ok" ]; then
  active_issue_rows="${active_issue_rows}<tr><td>sbom lifecycle maintenance</td><td>${sbom_ops_chip}</td><td>daily=${sbom_daily_status} (${sbom_daily_age_min}m, exit ${sbom_daily_exit_code}); weekly=${sbom_weekly_status} (${sbom_weekly_age_min}m, exit ${sbom_weekly_exit_code}); capability=${sbom_capability_mode} cve_map=${cve_mapping_supported}</td><td><span class=\"mono\">cat ${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}/cron-sbom-daily.json</span>; inspect <span class=\"mono\">/var/log/cron-reports/sbom-daily-*.log</span>; rerun <span class=\"mono\">/usr/local/sbin/sbom-daily-scan.ksh</span>; keep inventory-only fallback clearly labeled when CVE mapping is unavailable</td></tr>"
fi
if [ "${patch_ops_state}" != "ok" ]; then
  active_issue_rows="${active_issue_rows}<tr><td>patch lifecycle and regression gate</td><td>${patch_ops_chip}</td><td>weekly_4am=${cron_weekly_maintenance_4am}, apply_wrapper=${cron_weekly_maintenance_apply_wrapped}, post_wrapper=${cron_weekly_maintenance_post_reboot_wrapped}, daily_scan=${cron_daily_patch_scan}, regression_gate=${cron_regression_gate}, weekly_log_age=${weekly_maintenance_log_age_min}m, regression_log_age=${regression_gate_log_age_min}m, last_regression_pass=${maint_last_regression_pass}</td><td>keep wrapped weekly maintenance apply/post-reboot reports enabled, keep daily <span class=\"mono\">openbsd-syspatch.ksh --check</span>, and gate maintenance through <span class=\"mono\">maint-run.ksh --apply</span> or explicit <span class=\"mono\">regression-test.ksh --run</span></td></tr>"
fi
if [ "${reporting_ops_state}" != "ok" ]; then
  active_issue_rows="${active_issue_rows}<tr><td>change catalog and html reporting</td><td>${reporting_ops_chip}</td><td>MAILTO report email=${cron_mailto_ops}, html report jobs=${cron_html_report_count}, reports24h=${cron_reports_24h}, latest_age=${cron_report_latest_age_min}m</td><td>ensure root crontab keeps <span class=\"mono\">MAILTO=${MONITORING_PRIMARY_REPORT_EMAIL}</span>; keep cron-html-report wrappers enabled; validate fresh files under <span class=\"mono\">/var/log/cron-reports</span></td></tr>"
fi
if [ "${report_trust_ops_state}" != "ok" ]; then
  active_issue_rows="${active_issue_rows}<tr><td>report trust and config governance</td><td>${report_trust_ops_chip}</td><td>state=${report_trust_state}; false_green=${report_trust_false_green_count}; advisory=${report_trust_advisory_count}; reasons=${report_trust_reasons}; ssh_weekly=${ssh_hardening_weekly_status}/${ssh_hardening_weekly_age_min}m mismatch=${ssh_hardening_mismatch_count}; doas_weekly=${doas_policy_weekly_status}/${doas_policy_weekly_age_min}m drift=${doas_policy_drift}; maint_plan=${maint_plan_status} pending=${syspatch_pending_count}; sbom_daily=${sbom_daily_status} capability=${sbom_capability_mode} cve_map=${cve_mapping_supported}; weekly_structured=${weekly_maintenance_structured_report} apply=${weekly_maintenance_apply_status}/${weekly_maintenance_apply_age_display} post=${weekly_maintenance_post_status}/${weekly_maintenance_post_age_display}</td><td><span class=\"mono\">/bin/ksh ${MONITORING_SSH_HARDENING_SCRIPT:-/usr/local/sbin/ssh-hardening-window.ksh} --verify</span>; <span class=\"mono\">/bin/ksh ${MONITORING_DOAS_POLICY_SCRIPT:-/usr/local/sbin/openbsd-mailstack-doas-policy-transition} --check</span>; inspect <span class=\"mono\">${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}/cron-*.json</span> and <span class=\"mono\">/var/log/weekly-maintenance.log</span>; keep this control in <span class=\"mono\">documented operator review</span></td></tr>"
fi
if [ "${lifecycle_sdlc_state}" = "warn" ] || [ "${lifecycle_sdlc_state}" = "fail" ]; then
  active_issue_rows="${active_issue_rows}<tr><td>lifecycle maintenance / sdlc posture</td><td>${lifecycle_sdlc_chip}</td><td>reasons=${lifecycle_gap_reasons}; syspatch_pending=${syspatch_pending_count}; pkg_add_recent=${pkg_add_u_recent}; sbom_age=${sbom_report_age_min}m; cve_map=${cve_mapping_supported}</td><td>review <span class=\"mono\">host.html</span> lifecycle table; rerun maintenance checks and SBOM scan if stale; clear pending patch/package items</td></tr>"
fi
[ -n "${active_issue_rows}" ] || active_issue_rows="<tr><td>no active issue</td><td>$(status_chip ok)</td><td>all monitored issue gates passing</td><td>continue routine monitoring cadence</td></tr>"

changes=""
[ "${d_pf_states}" -ne 0 ] && changes="${changes}<li>pf state table changed by ${d_pf_states} since previous snapshot.</li>"
[ "${d_mail_queue}" -ne 0 ] && changes="${changes}<li>postfix queue changed by ${d_mail_queue}.</li>"
[ "${d_mail_accepted}" -ne 0 ] && changes="${changes}<li>mail accepted counter moved by ${d_mail_accepted}.</li>"
[ "${d_suricata_alerts}" -ne 0 ] && changes="${changes}<li>suricata alert volume changed by ${d_suricata_alerts}.</li>"
[ "${d_svc_fail}" -ne 0 ] && changes="${changes}<li>service failure count changed by ${d_svc_fail}.</li>"
[ -z "${changes}" ] && changes="<li>no significant counter change detected since previous snapshot.</li>"

make_tsv_trend_svg "${MAIL_TREND_TSV}" "${SPARK_DIR}/mail_accepted_48h.svg" "mail accepted events per hour (48h)" "#4de1ff"
make_tsv_trend_svg "${MAIL_CONNECT_TREND_TSV}" "${SPARK_DIR}/mail_connect_48h.svg" "mail inbound connection attempts per hour (48h)" "#59f2c7"
make_tsv_trend_svg "${MAIL_REJECT_TREND_TSV}" "${SPARK_DIR}/mail_rejected_48h.svg" "mail rejected and non-compliant attempts per hour (48h)" "#ff6b6b"
make_topn_tsv_bar_svg "${MAIL_NONCOMPLIANT_METHODS_TSV}" "${SPARK_DIR}/mail_noncompliant_methods_24h.svg" "mail non-compliant method mix (24h)" "#f5b942"
make_topn_tsv_bar_svg "${MAIL_CONNECTION_CATALOG_TSV}" "${SPARK_DIR}/mail_connection_catalog.svg" "mail connection event catalog (maillog history)" "#4de1ff"
make_topn_tsv_bar_svg "${MAIL_CONNECTION_SOURCES_TSV}" "${SPARK_DIR}/mail_connection_sources.svg" "mail top source addresses by attempt volume (maillog history)" "#59f2c7"
make_tsv_trend_svg "${SURICATA_TREND_TSV}" "${SPARK_DIR}/suricata_alerts_48h.svg" "suricata alert events per hour (48h)" "#b6ff3b"

overall_chip="$(status_chip "${overall}")"
mail_chip="$(status_chip "${mail_health}")"
verify_chip="$(status_chip "${verify_status}")"
svc_gate_chip="$(status_chip "${svc_gate_state}")"
verify_gate_chip="$(status_chip "${verify_gate_state}")"
cron_gate_chip="$(status_chip "${cron_gate_state}")"
queue_gate_chip="$(status_chip "${queue_gate_state}")"
pf_security_chip="$(status_chip "${pf_security_state}")"
tcp_security_chip="$(status_chip "${tcp_security_state}")"
udp_security_chip="$(status_chip "${udp_security_state}")"
cron_security_chip="$(status_chip "${cron_security_state}")"
verify_security_chip="$(status_chip "${verify_security_state}")"

render_page "${SITE_ROOT}/index.html" "monitor overview" <<EOF
<section class="card">
  <h2>executive narrative</h2>
  <p class="note">Current posture is ${overall} with service health ${svc_ok}/${svc_total}, mail queue ${mail_queue}, and gate summary <span class="mono">${overall_cause_html}</span>. This view combines live OpenBSD state, existing phase telemetry JSON, pfstat static timelines, and historical log parsing from <span class="mono">maillog*.gz</span> and <span class="mono">eve.json*.gz</span>.</p>
  <ul class="list">${overall_reason_items}</ul>
</section>

<section class="grid-1" style="margin-top:12px;">
  <article class="card">
    <h2>overall status</h2>
    <div class="kpi">${overall_chip}</div>
    <div class="stat"><span class="label">service health</span><span>${svc_ok}/${svc_total} (${svc_health_pct}%)</span></div>
    <div class="stat"><span class="label">verification</span><span>${verify_chip}</span></div>
    <div class="stat"><span class="label">critical / warning gates</span><span>${gate_critical_count} / ${gate_warn_count}</span></div>
    <div class="stat"><span class="label">primary cause</span><span class="mono">${overall_cause_html}</span></div>
    <div class="stat"><span class="label">incidents 24h</span><span>${incidents_24h}</span></div>
  </article>
  <article class="card">
    <h2>mail flow health</h2>
    <div class="kpi">${mail_chip}</div>
    <div class="stat"><span class="label">accepted (recent)</span><span>${mail_accepted}</span></div>
    <div class="stat"><span class="label">accepted (24h logs)</span><span>${mail_accepted_24h}</span></div>
    <div class="stat"><span class="label">active queue</span><span>${mail_queue}</span></div>
  </article>
  <article class="card">
    <h2>security posture</h2>
    <div class="kpi">${security_score}/100</div>
    <div class="stat"><span class="label">score model</span><span>100 - ${score_total_deduct} = ${security_score}</span></div>
    <div class="stat"><span class="label">policy public ports</span><span class="mono">${verify_public_ports}</span></div>
    <div class="stat"><span class="label">suricata blocked total</span><span>${suricata_blocked_totals}</span></div>
    <div class="stat"><span class="label">pf states</span><span>${pf_states}</span></div>
    <ul class="list" style="margin-top:8px;">${security_notes}</ul>
  </article>
  <article class="card">
    <h2>data freshness</h2>
    <div class="kpi">ages (min)</div>
    <div class="stat"><span class="label">pfstats/mailstats/suri</span><span>${pfstats_age_min}/${mailstats_age_min}/${suricata_age_min}</span></div>
    <div class="stat"><span class="label">verify</span><span>${verify_age_min}</span></div>
    <div class="stat"><span class="label">mail trend / suri trend</span><span>${mail_trend_age_min}/${suricata_trend_age_min}</span></div>
  </article>
</section>

<section class="card" style="margin-top:12px;">
  <h2>overall status decision trace</h2>
  <table class="table">
    <tr><th>gate</th><th>state</th><th>current</th><th>threshold</th><th>context and impact</th><th>remediation</th></tr>
    <tr>
      <td>service checks</td>
      <td>${svc_gate_chip}</td>
      <td>${svc_fail} failed daemon checks (${svc_fail_list_safe})</td>
      <td>critical if failed daemon checks &gt; 2</td>
      <td>daemon availability and control-plane health; excluded rcctl special-variable toggles: ${svc_non_daemon_count} (${svc_non_daemon_list_safe})</td>
      <td><span class="mono">rcctl check ${svc_fail_list_words}</span>; inspect <span class="mono">/var/log/messages</span>; see <span class="mono">host.html</span></td>
    </tr>
    <tr>
      <td>verify-mail-services</td>
      <td>${verify_gate_chip}</td>
      <td>${verify_status}</td>
      <td>expected PASS</td>
      <td>end-to-end mail policy and service verification</td>
      <td><span class="mono">cat ${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}/verify-mail-services.json</span>; run verify workflow and re-render monitor</td>
    </tr>
    <tr>
      <td>cron maintenance</td>
      <td>${cron_gate_chip}</td>
      <td>${cron_fail_count} fail / ${cron_warn_count} warn (${cron_jobs_summary})</td>
      <td>critical if fail &gt; 0, warning if warn &gt; 0</td>
      <td>maintenance/compliance evidence pipeline health; fail context: ${cron_fail_context_safe}</td>
      <td>open log path from context; rerun failed command from <span class="mono">${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}/cron-*.json</span>; reference <span class="mono">docs/ops/weekly-ops-cron-reporting.md</span></td>
    </tr>
    <tr>
      <td>mail queue depth</td>
      <td>${queue_gate_chip}</td>
      <td>${mail_queue}</td>
      <td>warn if &gt; 25, critical if &gt; 50</td>
      <td>mail delivery backlog pressure and throughput risk</td>
      <td><span class="mono">postqueue -p</span>; inspect <span class="mono">/var/log/maillog</span>; resolve stuck destinations</td>
    </tr>
  </table>
</section>

<section class="card" style="margin-top:12px;">
  <h2>security score decision trace</h2>
  <table class="table">
    <tr><th>control</th><th>state</th><th>current</th><th>threshold</th><th>deduction</th><th>remediation</th></tr>
    <tr>
      <td>pf enforcement</td>
      <td>${pf_security_chip}</td>
      <td>pf_enabled=${pf_enabled}</td>
      <td>must be enabled</td>
      <td>${score_pf_deduct}</td>
      <td><span class="mono">pfctl -s info</span>; validate pf service state and policy load</td>
    </tr>
    <tr>
      <td>public tcp exposure</td>
      <td>${tcp_security_chip}</td>
      <td>${public_tcp_count} listener(s): <span class="mono">${public_tcp_list}</span></td>
      <td>baseline max 3</td>
      <td>${score_tcp_deduct}</td>
      <td>compare with policy ports <span class="mono">${verify_public_ports}</span>; review nginx/pf listeners</td>
    </tr>
    <tr>
      <td>public udp exposure</td>
      <td>${udp_security_chip}</td>
      <td>${public_udp_count} listener(s): <span class="mono">${public_udp_list}</span></td>
      <td>baseline max 2</td>
      <td>${score_udp_deduct}</td>
      <td>confirm only required services are exposed (for example WireGuard and resolver)</td>
    </tr>
    <tr>
      <td>maintenance evidence pipeline</td>
      <td>${cron_security_chip}</td>
      <td>${cron_fail_count} fail / ${cron_warn_count} warn</td>
      <td>no failed jobs</td>
      <td>${score_cron_deduct}</td>
      <td>review <span class="mono">${cron_fail_context_safe}</span>; rerun failing job and validate next cron report PASS</td>
    </tr>
    <tr>
      <td>verify-mail-services</td>
      <td>${verify_security_chip}</td>
      <td>${verify_status}</td>
      <td>PASS</td>
      <td>${score_verify_deduct}</td>
      <td>inspect verify report details and remediate failing checks</td>
    </tr>
  </table>
</section>

<section class="card" style="margin-top:12px;">
  <h2>active issues and remediation queue</h2>
  <table class="table">
    <tr><th>issue</th><th>severity</th><th>evidence</th><th>remediation and references</th></tr>
    ${active_issue_rows}
  </table>
</section>

<section class="card" style="margin-top:12px;">
  <h2>enterprise ops control matrix (ticket keys)</h2>
  <div class="stat"><span class="label">controls failing / controls warning</span><span>fails: ${ops_control_fail}, warns: ${ops_control_warn}</span></div>
  <table class="table">
    <tr><th>ticket key</th><th>state</th><th>control objective</th><th>evidence</th><th>remediation/runbook</th></tr>
    <tr>
      <td class="mono">ops-mail-operational</td>
      <td>${mail_ops_chip}</td>
      <td>mail service remains operational and maillog telemetry stays current</td>
      <td>verify=${verify_status}; accepted_24h=${mail_accepted_24h}; queue=${mail_queue}; mailstats_age=${mailstats_age_min}m; maillog_trend_age=${mail_trend_age_min}m</td>
      <td><span class="mono">postqueue -p</span>; <span class="mono">tail -n 200 /var/log/maillog</span>; <span class="mono">rcctl check postfix rspamd dovecot</span>; inspect <span class="mono">mail.html</span></td>
    </tr>
    <tr>
      <td class="mono">ops-sbom-lifecycle</td>
      <td>${sbom_ops_chip}</td>
      <td>daily/weekly sbom scans for patch and software lifecycle risk are fresh, auditable, and capability-labeled</td>
      <td>daily=${sbom_daily_status} age=${sbom_daily_age_min}m exit=${sbom_daily_exit_code}; weekly=${sbom_weekly_status} age=${sbom_weekly_age_min}m exit=${sbom_weekly_exit_code}; capability=${sbom_capability_mode} cve_map=${cve_mapping_supported}</td>
      <td><span class="mono">cat ${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}/cron-sbom-daily.json</span>; review <span class="mono">/var/log/cron-reports/sbom-*.log</span>; run <span class="mono">/usr/local/sbin/sbom-daily-scan.ksh</span>; see <span class="mono">docs/ops/sbom-daily-scan-and-exceptions.md</span></td>
    </tr>
    <tr>
      <td class="mono">ops-suricata-active-block</td>
      <td>${suricata_ops_chip}</td>
      <td>suricata must run in active block mode and produce fresh reporting</td>
      <td>suricata_status=${suricata_status}; mode_block_cron=${suricata_mode_block_cron}; suricata_age=${suricata_age_min}m; trend_age=${suricata_trend_age_min}m; blocked=${suricata_blocked_totals}</td>
      <td><span class="mono">rcctl check suricata</span>; verify root cron line <span class="mono">MODE=block ... suricata_eve2pf.ksh</span>; inspect <span class="mono">/var/log/suricata/eve.json</span> and <span class="mono">ids.html</span></td>
    </tr>
    <tr>
      <td class="mono">ops-pf-reactive-enforcement</td>
      <td>${pf_ops_chip}</td>
      <td>pf stays enabled and reacts to suricata by enforcing block/allow tables</td>
      <td>pf_enabled=${pf_enabled}; suricata_watch=${table_suricata_watch}; suricata_block=${table_suricata_block}; suricata_allow=${table_suricata_allow}; eve2pf_mode=${suricata_eve2pf_mode}; eve2pf_candidates=${suricata_eve2pf_candidates}; eve2pf_window_s=${suricata_eve2pf_window_s}; eve2pf_log_age=${suricata_eve2pf_log_age_min}m</td>
      <td><span class="mono">pfctl -s info</span>; <span class="mono">pfctl -t suricata_block -T show</span>; validate suricata->pf pipeline and anchors</td>
    </tr>
    <tr>
      <td class="mono">ops-patch-weekly-and-daily-scan</td>
      <td>${patch_ops_chip}</td>
      <td>weekly patch apply at 04:30 plus daily critical patch scan, with regression test gate</td>
      <td>weekly_4am=${cron_weekly_maintenance_4am}; apply_wrapper=${cron_weekly_maintenance_apply_wrapped}; post_wrapper=${cron_weekly_maintenance_post_reboot_wrapped}; daily_scan=${cron_daily_patch_scan}; regression_gate=${cron_regression_gate}; weekly_log_age=${weekly_maintenance_log_age_min}m; maint_log_age=${maint_last_log_age_min}m; regression_log_age=${regression_gate_log_age_min}m; pending_reboot_verify=${weekly_maintenance_pending}; last_regression_pass=${maint_last_regression_pass}</td>
      <td>keep wrapped weekly maintenance apply/post-reboot reports enabled; add daily <span class="mono">openbsd-syspatch.ksh --check</span> wrapper; gate patch runs via <span class="mono">maint-run.ksh --apply</span> or explicit <span class="mono">regression-test.ksh --run</span></td>
    </tr>
    <tr>
      <td class="mono">ops-change-catalog-email</td>
      <td>${reporting_ops_chip}</td>
      <td>all maintenance/change actions are cataloged and emailed as html reports to ops</td>
      <td>root_mailto_ops=${cron_mailto_ops}; html_report_jobs=${cron_html_report_count}; reports_last24h=${cron_reports_24h}; latest_report_age=${cron_report_latest_age_min}m</td>
      <td>ensure root crontab includes <span class="mono">MAILTO=${MONITORING_PRIMARY_REPORT_EMAIL}</span>; keep <span class="mono">cron-html-report.ksh</span> wrappers; verify fresh files under <span class="mono">/var/log/cron-reports</span></td>
    </tr>
    <tr>
      <td class="mono">ops-report-trust-governance</td>
      <td>${report_trust_ops_chip}</td>
      <td>high-risk daemon/config governance and cron evidence must stay semantically accurate without autonomous risky actions</td>
      <td>state=${report_trust_state}; false_green=${report_trust_false_green_count}; advisory=${report_trust_advisory_count}; reasons=${report_trust_reasons}; ssh=${ssh_hardening_weekly_status}/${ssh_hardening_weekly_age_min}m mismatch=${ssh_hardening_mismatch_count} runtime=${ssh_hardening_state}; doas=${doas_policy_weekly_status}/${doas_policy_weekly_age_min}m drift=${doas_policy_drift} valid=${doas_live_valid}; maint_plan=${maint_plan_status} pending=${syspatch_pending_count}; sbom_daily=${sbom_daily_status} capability=${sbom_capability_mode} cve_map=${cve_mapping_supported}; weekly_structured=${weekly_maintenance_structured_report} apply=${weekly_maintenance_apply_status}/${weekly_maintenance_apply_age_display} post=${weekly_maintenance_post_status}/${weekly_maintenance_post_age_display}</td>
      <td><span class="mono">/bin/ksh ${MONITORING_SSH_HARDENING_SCRIPT:-/usr/local/sbin/ssh-hardening-window.ksh} --verify</span>; <span class="mono">/bin/ksh ${MONITORING_DOAS_POLICY_SCRIPT:-/usr/local/sbin/openbsd-mailstack-doas-policy-transition} --check</span>; inspect <span class="mono">${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}/cron-*.json</span>; keep policy at <span class="mono">documented operator review</span> because this control is read-only governance</td>
    </tr>
  </table>
  <p class="note">These ticket keys are stable identifiers for agent-driven incident creation, deduplication, and closure when state transitions occur.</p>
</section>

<section class="card" style="margin-top:12px;">
  <h2>phase-14 semi-autonomous actions behavior</h2>
  <div class="stat"><span class="label">agent behavior</span><span>${agent_behavior_chip}</span></div>
  <div class="stat"><span class="label">mode / updated</span><span>${agent_mode_chip} <span class="mono">${agent_mode_desc_h}</span> · <span class="mono">${agent_updated_iso}</span> (${agent_updated_age_min}m)</span></div>
  <div class="stat"><span class="label">queue severity</span><span>${agent_queue_chip} fail=${agent_queue_fail_count}, warn_or_other=${agent_queue_warn_count}, total=${agent_queue_count}</span></div>
  <div class="stat"><span class="label">trust and integrity</span><span>${agent_upstream_trust_chip} <span class="mono">${agent_upstream_trust_state_raw}</span> · ${agent_policy_trust_chip} <span class="mono">${agent_policy_trust_state_raw}</span></span></div>
  <div class="stat"><span class="label">emergency / approval</span><span>${agent_top_emergency_chip} emergency=${agent_emergency_open}, approval_required=${agent_approval_required}, refusals=${agent_input_refusals}</span></div>
  <div class="stat"><span class="label">action outcomes</span><span>${agent_action_summary_chip} attempted=${agent_actions_attempted}, ok=${agent_actions_ok}, failed=${agent_actions_failed}</span></div>
  <div class="stat"><span class="label">risk in summary</span><span>high_or_critical=${agent_queue_high_risk}, medium=${agent_queue_medium_risk}, low=${agent_queue_low_risk}</span></div>
  <div class="stat"><span class="label">policy in summary</span><span>manual=${agent_policy_manual}, assist=${agent_policy_assist}, auto_safe=${agent_policy_auto_safe}</span></div>
  <div class="stat"><span class="label">summary consistency</span><span>${agent_summary_consistency_chip} queue-summary delta=${agent_summary_queue_delta}</span></div>
  <table class="table">
    <tr><th>control key</th><th>risk</th><th>trust</th><th>emergency</th><th>approval</th><th>action state</th><th>open age</th><th>runbook action</th></tr>
    ${agent_queue_rows_short}
  </table>
  <table class="table" style="margin-top:10px;">
    <tr><th>executed (utc)</th><th>control key</th><th>action state</th><th>rc</th><th>duration</th></tr>
    ${agent_action_rows_short}
  </table>
  <p class="note">${agent_action_expectation_note}</p>
  <ul class="list" style="margin-top:8px;">${agent_changes}</ul>
  <p class="note">full phase-14 detail is available on <a href="agent.html">agent.html</a>.</p>
</section>

<section class="card" style="margin-top:12px;">
  <h2>what changed</h2>
  <ul class="list">${changes}</ul>
</section>

<section class="grid-1" style="margin-top:12px;">
  <article class="card">
    <h2>pf state timeline (pfstat)</h2>
    <img class="pfimg" src="${PFSTAT_BASE_URL}/states_day.jpg" alt="pf states day timeline">
    <div class="note">source: existing pfstat static image pipeline under <span class="mono">${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}stat</span>.</div>
  </article>
  <article class="card">
    <h2>mail accepted trend (48h)</h2>
    <img class="trend-lg" src="sparklines/mail_accepted_48h.svg" alt="mail accepted 48h trend">
    <div class="stat"><span class="label">last hour</span><span>${mail_accepted_1h}/hr</span></div>
    <div class="stat"><span class="label">last 24h</span><span>${mail_accepted_24h}</span></div>
    <div class="note">derived from <span class="mono">/var/log/maillog</span> and <span class="mono">/var/log/maillog.*.gz</span>.</div>
  </article>
  <article class="card">
    <h2>suricata alerts trend (48h)</h2>
    <img class="trend-lg" src="sparklines/suricata_alerts_48h.svg" alt="suricata alerts 48h trend">
    <div class="stat"><span class="label">last hour</span><span>${suricata_alerts_1h}/hr</span></div>
    <div class="stat"><span class="label">last 24h</span><span>${suricata_alerts_24h}</span></div>
    <div class="note">derived from <span class="mono">/var/log/suricata/eve.json</span> and rotated <span class="mono">eve.json*.gz</span>.</div>
  </article>
</section>
EOF

render_page "${SITE_ROOT}/host.html" "host metrics" <<EOF
<section class="grid">
  <article class="card">
    <h2>load and cpu</h2>
    <div class="stat"><span class="label">load avg</span><span>${load_1} ${load_5} ${load_15}</span></div>
    <div class="stat"><span class="label">cpu idle</span><span>${cpu_idle_pct}%</span></div>
    <div class="stat"><span class="label">cpu user/sys</span><span>$(kv_get "${latest}" cpu_user_pct 0)% / $(kv_get "${latest}" cpu_sys_pct 0)%</span></div>
    <div class="stat"><span class="label">uptime</span><span class="mono">$(html_escape "$(kv_get "${latest}" uptime_line "unknown")")</span></div>
  </article>
  <article class="card">
    <h2>memory snapshot</h2>
    <div class="stat"><span class="label">vm avm</span><span>$(kv_get "${latest}" mem_avm 0)</span></div>
    <div class="stat"><span class="label">vm free</span><span>$(kv_get "${latest}" mem_free 0)</span></div>
  </article>
  <article class="card">
    <h2>service rollup</h2>
    <div class="stat"><span class="label">enabled services</span><span>${svc_total}</span></div>
    <div class="stat"><span class="label">healthy checks</span><span>${svc_ok}</span></div>
    <div class="stat"><span class="label">failed checks</span><span>${svc_fail}</span></div>
    <div class="stat"><span class="label">failed list</span><span class="mono">${svc_fail_list}</span></div>
    <div class="stat"><span class="label">excluded rcctl toggles</span><span>${svc_non_daemon_count}</span></div>
    <div class="stat"><span class="label">toggle list</span><span class="mono">${svc_non_daemon_list}</span></div>
  </article>
</section>

<section class="grid" style="margin-top:12px;">
  <article class="card span-all">
    <h2>lifecycle maintenance and sdlc posture</h2>
    <div class="stat"><span class="label">overall lifecycle state</span><span>${lifecycle_sdlc_chip}</span></div>
    <div class="stat"><span class="label">gap reasons</span><span class="mono">${lifecycle_gap_reasons}</span></div>
    <table class="table" style="margin-top:10px;">
      <tr><th>question</th><th>status</th><th>evidence</th><th>evidence age</th><th>notes</th></tr>
      <tr>
        <td>are syspatch updates current?</td>
        <td>${lifecycle_syspatch_chip}</td>
        <td>pending=${syspatch_pending_count}; installed=${syspatch_installed_count}; pending ids=<span class="mono">${syspatch_pending_display_h}</span>; live check=<span class="mono">${syspatch_check_summary}</span>; maint-plan status=${maint_plan_status} exit=${maint_plan_exit_code}</td>
        <td>${syspatch_evidence_age_display}</td>
        <td>maint-plan log: <span class="mono">${maint_plan_log_file}</span></td>
      </tr>
      <tr>
        <td>has <span class="mono">pkg_add -u</span> been run?</td>
        <td>${lifecycle_pkg_chip}</td>
        <td>runs=${pkg_upgrade_runs_total}; last run=<span class="mono">${pkg_last_run_display_h}</span>; last apply=<span class="mono">${pkg_last_apply_display_h}</span>; post-reboot verify=<span class="mono">${pkg_upgrade_last_post_verify_status}</span> at <span class="mono">${pkg_last_post_display_h}</span></td>
        <td>run=${pkg_upgrade_last_run_age_min}m; apply=${pkg_upgrade_last_apply_age_min}m</td>
        <td>pkg snapshot: age=${pkg_snapshot_age_min}m, packages=${pkg_snapshot_count}, recent_window_ok=${pkg_add_u_recent}</td>
      </tr>
      <tr>
        <td>is there a software update gap against expected cadence?</td>
        <td>${lifecycle_sdlc_chip}</td>
        <td>weekly_pending=${weekly_maintenance_pending}; weekly_log_age=${weekly_maintenance_log_age_min}m; daily_scan_cron=${cron_daily_patch_scan}; regression_gate=${cron_regression_gate}</td>
        <td>latest lifecycle evidence ${cron_report_latest_age_min}m</td>
        <td>expected cadence: daily plan checks + weekly apply/reboot verification cycle</td>
      </tr>
      <tr>
        <td>does current telemetry show CVE-associated findings?</td>
        <td>${lifecycle_cve_chip}</td>
        <td>scanner=<span class="mono">${sbom_scanner}</span>; cve_findings=${cve_findings_display}; severity total=${sbom_vuln_total} (c=${sbom_severity_critical}, h=${sbom_severity_high}, m=${sbom_severity_medium}, l=${sbom_severity_low}, u=${sbom_severity_unknown}); exceptions total/expired/invalid=${sbom_exceptions_total}/${sbom_exceptions_expired}/${sbom_exceptions_invalid}</td>
        <td>${sbom_report_age_min}m</td>
        <td>${cve_summary_note}</td>
      </tr>
    </table>
    <p class="note">This posture card is evidence-driven from <span class="mono">cron-maint-plan-daily</span>, <span class="mono">weekly-maintenance.log</span>, package snapshot, and SBOM report artifacts.</p>
  </article>
</section>
EOF

render_page "${SITE_ROOT}/network.html" "network and exposure" <<EOF
<section class="grid">
  <article class="card">
    <h2>listener inventory</h2>
    <div class="stat"><span class="label">tcp listeners</span><span>${tcp_listen_count}</span></div>
    <div class="stat"><span class="label">udp wildcard listeners</span><span>${udp_listener_count}</span></div>
    <div class="stat"><span class="label">public tcp listeners</span><span>${public_tcp_count}</span></div>
    <div class="stat"><span class="label">public udp listeners</span><span>${public_udp_count}</span></div>
  </article>
  <article class="card">
    <h2>public endpoints</h2>
    <div class="stat"><span class="label">verify policy ports</span><span class="mono">${verify_public_ports}</span></div>
    <div class="stat"><span class="label">tcp list</span><span class="mono">${public_tcp_list}</span></div>
    <div class="stat"><span class="label">udp list</span><span class="mono">${public_udp_list}</span></div>
  </article>
</section>

<section class="grid-2" style="margin-top:12px;">
  <article class="card">
    <h2>interface counter exceptions</h2>
    <table class="table">
      <tr><th>interface</th><th>network</th><th>address</th><th>ifail / ofail / colls</th><th>operator note</th></tr>
      ${network_interface_issue_rows}
    </table>
  </article>
  <article class="card">
    <h2>recent network-device log issues</h2>
    <table class="table">
      <tr><th>issue</th><th>count</th><th>last seen</th><th>evidence</th></tr>
      ${network_log_issue_rows}
    </table>
    <p class="note">Log scan covers the current <span class="mono">/var/log/messages</span> file and highlights ARP ownership churn plus common link, carrier, timeout, and media mismatch warnings.</p>
  </article>
</section>
EOF

render_page "${SITE_ROOT}/pf.html" "packet filter" <<EOF
<section class="grid">
  <article class="card">
    <h2>pf core</h2>
    <div class="stat"><span class="label">enabled</span><span>${pf_enabled}</span></div>
    <div class="stat"><span class="label">states</span><span>${pf_states}</span></div>
    <div class="stat"><span class="label">tables</span><span>${pf_tables}</span></div>
    <div class="stat"><span class="label">synproxy matches</span><span>$(kv_get "${latest}" pf_synproxy 0)</span></div>
  </article>
  <article class="card">
    <h2>packet counters</h2>
    <div class="stat"><span class="label">in blocked</span><span>${pf_packets_in_block}</span></div>
    <div class="stat"><span class="label">in passed</span><span>$(kv_get "${latest}" pf_packets_in_pass 0)</span></div>
    <div class="stat"><span class="label">out blocked</span><span>$(kv_get "${latest}" pf_packets_out_block 0)</span></div>
    <div class="stat"><span class="label">out passed</span><span>$(kv_get "${latest}" pf_packets_out_pass 0)</span></div>
  </article>
  <article class="card">
    <h2>abuse and ids tables</h2>
    <div class="stat"><span class="label">sshguard</span><span>$(kv_get "${latest}" table_sshguard 0)</span></div>
    <div class="stat"><span class="label">smtp_abuse</span><span>$(kv_get "${latest}" table_smtp_abuse 0)</span></div>
    <div class="stat"><span class="label">suricata_block</span><span>$(kv_get "${latest}" table_suricata_block 0)</span></div>
    <div class="stat"><span class="label">suricata_allow</span><span>$(kv_get "${latest}" table_suricata_allow 0)</span></div>
  </article>
</section>

<section class="grid-1" style="margin-top:12px;">
  <article class="card"><h2>pf states (day)</h2><img class="pfimg-xl" src="${PFSTAT_BASE_URL}/states_day.jpg" alt="pf states day"></article>
  <article class="card"><h2>pf states (week)</h2><img class="pfimg-xl" src="${PFSTAT_BASE_URL}/states_week.jpg" alt="pf states week"></article>
  <article class="card"><h2>pf states (month)</h2><img class="pfimg-xl" src="${PFSTAT_BASE_URL}/states_month.jpg" alt="pf states month"></article>
</section>

<section class="grid" style="margin-top:12px;">
  <article class="card span-all">
    <h2>pfstat detail view</h2>
    <div class="stat"><span class="label">pfstat source age</span><span>${pfstats_age_min} min</span></div>
    <div class="note">reference view: <a href="/pf/pfstat.html">/pf/pfstat.html</a></div>
    <div class="note">source assets: <span class="mono">${PFSTAT_BASE_URL}/traffic_*.jpg</span>, <span class="mono">${PFSTAT_BASE_URL}/packets_*.jpg</span>, and <span class="mono">${PFSTAT_BASE_URL}/states_*.jpg</span>.</div>
  </article>
</section>

<section class="grid" style="margin-top:12px;">
  <article class="card">
    <h2>pf traffic (day)</h2>
    <img class="pfimg" src="${PFSTAT_BASE_URL}/traffic_day.jpg" alt="pf traffic and states day">
  </article>
  <article class="card">
    <h2>pf traffic (week)</h2>
    <img class="pfimg" src="${PFSTAT_BASE_URL}/traffic_week.jpg" alt="pf traffic and states week">
  </article>
  <article class="card">
    <h2>pf traffic (month)</h2>
    <img class="pfimg" src="${PFSTAT_BASE_URL}/traffic_month.jpg" alt="pf traffic and states month">
  </article>
</section>

<section class="grid" style="margin-top:12px;">
  <article class="card">
    <h2>pf packets (day)</h2>
    <img class="pfimg" src="${PFSTAT_BASE_URL}/packets_day.jpg" alt="pf pass and block packets day">
  </article>
  <article class="card">
    <h2>pf packets (week)</h2>
    <img class="pfimg" src="${PFSTAT_BASE_URL}/packets_week.jpg" alt="pf pass and block packets week">
  </article>
  <article class="card">
    <h2>pf packets (month)</h2>
    <img class="pfimg" src="${PFSTAT_BASE_URL}/packets_month.jpg" alt="pf pass and block packets month">
  </article>
</section>

<section class="grid" style="margin-top:12px;">
  <article class="card">
    <h2>pf state detail (day)</h2>
    <img class="pfimg" src="${PFSTAT_BASE_URL}/states_day.jpg" alt="pf state activity detail day">
  </article>
  <article class="card">
    <h2>pf state detail (week)</h2>
    <img class="pfimg" src="${PFSTAT_BASE_URL}/states_week.jpg" alt="pf state activity detail week">
  </article>
  <article class="card">
    <h2>pf state detail (month)</h2>
    <img class="pfimg" src="${PFSTAT_BASE_URL}/states_month.jpg" alt="pf state activity detail month">
  </article>
</section>
EOF

render_page "${SITE_ROOT}/mail.html" "mail pipeline" <<EOF
<section class="grid">
  <article class="card">
    <h2>postfix flow</h2>
    <div class="stat"><span class="label">accepted (window)</span><span>${mail_accepted}</span></div>
    <div class="stat"><span class="label">accepted (24h logs)</span><span>${mail_accepted_24h}</span></div>
    <div class="stat"><span class="label">incoming connects (24h)</span><span>${mail_connect_24h}</span></div>
    <div class="stat"><span class="label">rejected (window)</span><span>${mail_rejected}</span></div>
    <div class="stat"><span class="label">rejected (24h logs)</span><span>${mail_rejected_24h}</span></div>
    <div class="stat"><span class="label">rejected (latest hour)</span><span>${mail_rejected_1h}</span></div>
    <div class="stat"><span class="label">bounced/deferred</span><span>$(kv_get "${latest}" mail_bounced 0) / $(kv_get "${latest}" mail_deferred 0)</span></div>
    <div class="stat"><span class="label">queue</span><span>${mail_queue}</span></div>
  </article>
  <article class="card">
    <h2>rspamd actions</h2>
    <div class="stat"><span class="label">reject</span><span>${rspamd_reject}</span></div>
    <div class="stat"><span class="label">add header</span><span>${rspamd_add_header}</span></div>
    <div class="stat"><span class="label">greylist</span><span>${rspamd_greylist}</span></div>
    <div class="stat"><span class="label">soft reject</span><span>${rspamd_soft_reject}</span></div>
  </article>
  <article class="card">
    <h2>verification and vt</h2>
    <div class="stat"><span class="label">verify status</span><span>${verify_chip}</span></div>
    <div class="stat"><span class="label">verify fail/warn</span><span>$(kv_get "${latest}" verify_fail 0) / $(kv_get "${latest}" verify_warn 0)</span></div>
    <div class="stat"><span class="label">vt checks/errors</span><span>${vt_checks} / ${vt_errors}</span></div>
  </article>
  <article class="card">
    <h2>non-compliant usage attempts</h2>
    <div class="stat"><span class="label">attempts (24h)</span><span>${mail_noncompliant_attempts_24h}</span></div>
    <div class="stat"><span class="label">attempts (history catalog)</span><span>${mail_connection_noncompliant_total}</span></div>
    <div class="stat"><span class="label">methods data age</span><span>${mail_noncompliant_methods_age_min} min</span></div>
    <div class="note">top methods: <span class="mono">${mail_noncompliant_top_methods_inline}</span></div>
  </article>
  <article class="card span-all">
    <h2>catalog coverage</h2>
    <div class="stat"><span class="label">attempt events (history)</span><span>${mail_connection_events_total}</span></div>
    <div class="stat"><span class="label">rejected events (history)</span><span>${mail_connection_rejected_total}</span></div>
    <div class="stat"><span class="label">log files scanned</span><span>${mail_log_files_scanned}</span></div>
    <div class="stat"><span class="label">log lines scanned</span><span>${mail_connection_lines_scanned}</span></div>
    <div class="stat"><span class="label">catalog/source age</span><span>${mail_connection_catalog_age_min} / ${mail_connection_sources_age_min} min</span></div>
    <div class="note">top catalog entries: <span class="mono">${mail_connection_catalog_top_inline}</span></div>
    <div class="note">top source ips: <span class="mono">${mail_connection_source_top_inline}</span></div>
  </article>
</section>

<section class="grid-2" style="margin-top:12px;">
  <article class="card">
    <h2>incoming connection attempts trend (48h)</h2>
    <img class="trend-lg" src="sparklines/mail_connect_48h.svg" alt="mail inbound connection attempts 48h trend">
    <div class="stat"><span class="label">latest hour</span><span>${mail_connect_1h}</span></div>
    <div class="stat"><span class="label">last 24h</span><span>${mail_connect_24h}</span></div>
    <div class="stat"><span class="label">trend data age</span><span>${mail_connect_trend_age_min} min</span></div>
  </article>
  <article class="card">
    <h2>mail accepted trend (48h from maillog history)</h2>
    <img class="trend-lg" src="sparklines/mail_accepted_48h.svg" alt="mail accepted 48h trend">
    <div class="stat"><span class="label">latest hour</span><span>${mail_accepted_1h}</span></div>
    <div class="stat"><span class="label">trend data age</span><span>${mail_trend_age_min} min</span></div>
  </article>
  <article class="card">
    <h2>incoming rejected attempts trend (48h)</h2>
    <img class="trend-lg" src="sparklines/mail_rejected_48h.svg" alt="mail rejected and non-compliant attempts 48h trend">
    <div class="stat"><span class="label">latest hour</span><span>${mail_rejected_1h}</span></div>
    <div class="stat"><span class="label">last 24h</span><span>${mail_rejected_24h}</span></div>
    <div class="stat"><span class="label">trend data age</span><span>${mail_reject_trend_age_min} min</span></div>
    <div class="note">derived from rejected smtpd events plus postscreen protocol-hygiene rejects in <span class="mono">/var/log/maillog*</span>.</div>
  </article>
  <article class="card">
    <h2>non-compliant method mix (24h)</h2>
    <img class="trend-lg" src="sparklines/mail_noncompliant_methods_24h.svg" alt="mail non-compliant method mix 24h">
    <div class="stat"><span class="label">attempts (24h)</span><span>${mail_noncompliant_attempts_24h}</span></div>
    <div class="stat"><span class="label">methods data age</span><span>${mail_noncompliant_methods_age_min} min</span></div>
  </article>
</section>

<section class="grid-2" style="margin-top:12px;">
  <article class="card">
    <h2>connection event catalog (history)</h2>
    <img class="trend-lg" src="sparklines/mail_connection_catalog.svg" alt="mail connection event catalog from maillog history">
    <div class="stat"><span class="label">catalog data age</span><span>${mail_connection_catalog_age_min} min</span></div>
    <table class="table topn-data-table" style="margin-top:8px;">
      <tr><th>event token</th><th>count</th></tr>
      ${mail_connection_catalog_rows}
    </table>
  </article>
  <article class="card">
    <h2>top source addresses (history)</h2>
    <img class="trend-lg" src="sparklines/mail_connection_sources.svg" alt="mail top source addresses from maillog history">
    <div class="stat"><span class="label">source data age</span><span>${mail_connection_sources_age_min} min</span></div>
    <table class="table topn-data-table" style="margin-top:8px;">
      <tr><th>source ip</th><th>attempts</th></tr>
      ${mail_connection_source_rows}
    </table>
  </article>
</section>

<section class="card" style="margin-top:12px;">
  <h2>top non-compliant methods (24h)</h2>
  <table class="table methods-table">
    <tr><th>method token</th><th>attempts</th><th>description</th></tr>
    ${mail_noncompliant_method_rows}
  </table>
  <p class="note">Descriptions are heuristic interpretations from postscreen/smtpd reject patterns in <span class="mono">/var/log/maillog*</span>.</p>
</section>
EOF

render_page "${SITE_ROOT}/rspamd.html" "rspamd details" <<EOF
<section class="card">
  <h2>rspamd health detail</h2>
  <table class="table">
    <tr><th>metric</th><th>value</th></tr>
    <tr><td>reject</td><td>${rspamd_reject}</td></tr>
    <tr><td>add header</td><td>${rspamd_add_header}</td></tr>
    <tr><td>greylist</td><td>${rspamd_greylist}</td></tr>
    <tr><td>soft reject</td><td>${rspamd_soft_reject}</td></tr>
    <tr><td>vt checks</td><td>${vt_checks}</td></tr>
    <tr><td>vt errors</td><td>${vt_errors}</td></tr>
    <tr><td>mailstats age</td><td>${mailstats_age_min} min</td></tr>
  </table>
  <p class="note">quick log command: <span class="mono">tail -n 80 /var/log/rspamd/rspamd.log</span></p>
</section>
EOF

render_page "${SITE_ROOT}/dovecot.html" "dovecot status" <<EOF
<section class="card">
  <h2>dovecot posture</h2>
  <table class="table">
    <tr><th>check</th><th>value</th></tr>
    <tr><td>wg interface present</td><td>${wg_iface_present}</td></tr>
    <tr><td>verify status</td><td>${verify_status}</td></tr>
    <tr><td>service failures (global)</td><td>${svc_fail}</td></tr>
    <tr><td>recommended command</td><td class="mono">rcctl check dovecot; netstat -an -p tcp | grep '.993'</td></tr>
  </table>
</section>
EOF

render_page "${SITE_ROOT}/postfix.html" "postfix status" <<EOF
<section class="card">
  <h2>postfix posture</h2>
  <table class="table">
    <tr><th>metric</th><th>value</th></tr>
    <tr><td>queue depth</td><td>${mail_queue}</td></tr>
    <tr><td>accepted (window)</td><td>${mail_accepted}</td></tr>
    <tr><td>accepted (24h logs)</td><td>${mail_accepted_24h}</td></tr>
    <tr><td>rejected</td><td>${mail_rejected}</td></tr>
    <tr><td>bounced</td><td>$(kv_get "${latest}" mail_bounced 0)</td></tr>
    <tr><td>deferred</td><td>$(kv_get "${latest}" mail_deferred 0)</td></tr>
    <tr><td>recommended command</td><td class="mono">postqueue -p; zgrep -h 'status=sent' /var/log/maillog* | tail</td></tr>
  </table>
</section>
EOF

render_page "${SITE_ROOT}/web.html" "web tier" <<EOF
<section class="grid">
  <article class="card">
    <h2>nginx and php-fpm</h2>
    <div class="stat"><span class="label">nginx config test</span><span>${nginx_conf_ok}</span></div>
    <div class="stat"><span class="label">127.0.0.1:443 listener</span><span>${nginx_https_loop_listener}</span></div>
    <div class="stat"><span class="label">10.44.0.1:443 listener</span><span>${nginx_https_wg_listener}</span></div>
    <div class="stat"><span class="label">public tcp listeners</span><span>${public_tcp_count}</span></div>
  </article>
  <article class="card">
    <h2>cron report state</h2>
    <div class="stat"><span class="label">cron fails</span><span>${cron_fail_count}</span></div>
    <div class="stat"><span class="label">cron warns</span><span>${cron_warn_count}</span></div>
    <div class="stat"><span class="label">failed jobs</span><span class="mono">${cron_fail_jobs}</span></div>
    <div class="stat"><span class="label">warn jobs</span><span class="mono">${cron_warn_jobs}</span></div>
  </article>
</section>

<section class="card" style="margin-top:12px;">
  <h2>valid url inventory</h2>
  <div class="stat"><span class="label">primary fqdn</span><span class="mono">${web_primary_host_display}</span></div>
  <div class="stat"><span class="label">urls checked</span><span>${web_url_total}</span></div>
  <div class="stat"><span class="label">up / restricted / down</span><span>${web_url_up} / ${web_url_restricted} / ${web_url_down}</span></div>
  <table class="table">
    <tr><th>full url</th><th>service</th><th>status</th><th>http code</th></tr>
    ${web_url_rows}
  </table>
  <p class="note">${web_url_probe_note_display}</p>
</section>
EOF

dns_backup_state="ok"
if [ "${dns_vultr_age_min}" -lt 0 ]; then
  dns_backup_state="fail"
elif [ "${dns_vultr_age_min}" -gt 1560 ]; then
  dns_backup_state="warn"
fi
dns_backup_chip="$(status_chip "${dns_backup_state}")"
dns_backup_age_display="${dns_vultr_age_min} min"
[ "${dns_vultr_age_min}" -lt 0 ] && dns_backup_age_display="n/a"

dns_domain_names="none"
dns_domain_rows="<tr><td colspan=\"4\">no authoritative Vultr DNS snapshot is present in the latest Phase 10 mailstack backup</td></tr>"
if [ -r "${dns_vultr_manifest_path}" ] && command -v jq >/dev/null 2>&1; then
  dns_domain_names="$(jq -r '.domains | sort_by(.domain) | map(.domain) | join(" | ")' "${dns_vultr_manifest_path}" 2>/dev/null || printf 'none')"
  dns_domain_rows="$(
    jq -r '
      .domains
      | sort_by(.domain)
      | .[]
      | [
          (.domain // "unknown"),
          ((.record_count // 0) | tostring),
          ((.type_counts // {}) | to_entries | sort_by(.key) | map("\(.key)=\(.value)") | join(", ")),
          ((.json_file // "n/a") + " | " + (.xml_file // "n/a"))
        ]
      | @tsv
    ' "${dns_vultr_manifest_path}" 2>/dev/null | while IFS='	' read -r _dom _count _types _files; do
      printf '<tr><td class="mono">%s</td><td>%s</td><td class="mono">%s</td><td class="mono">%s</td></tr>\n' \
        "$(html_escape "${_dom}")" \
        "$(html_escape "${_count}")" \
        "$(html_escape "${_types}")" \
        "$(html_escape "${_files}")"
    done
  )"
  [ -n "${dns_domain_rows}" ] || dns_domain_rows="<tr><td colspan=\"4\">DNS manifest was present but no domain rows were rendered</td></tr>"
fi

render_page "${SITE_ROOT}/dns.html" "dns posture" <<EOF
<section class="grid-2">
  <article class="card">
    <h2>resolver posture</h2>
    <table class="table">
      <tr><th>metric</th><th>value</th></tr>
      <tr><td>wg interface present</td><td>${wg_iface_present}</td></tr>
      <tr><td>public udp listeners</td><td>${public_udp_count}</td></tr>
      <tr><td>public udp list</td><td class="mono">${public_udp_list}</td></tr>
      <tr><td>recommended command</td><td class="mono">netstat -an -p udp | grep '.53'; rcctl check unbound</td></tr>
    </table>
  </article>
  <article class="card">
    <h2>authoritative zone backup</h2>
    <div class="kpi">${dns_backup_chip}</div>
    <div class="stat"><span class="label">snapshot age</span><span>${dns_backup_age_display}</span></div>
    <div class="stat"><span class="label">generated at</span><span class="mono">${dns_vultr_generated_at}</span></div>
    <div class="stat"><span class="label">managed domains / records</span><span>${dns_vultr_domain_count} / ${dns_vultr_record_count}</span></div>
    <div class="stat"><span class="label">mailstack archive</span><span class="mono">${backup_mailstack_latest_path}</span></div>
    <div class="stat"><span class="label">snapshot dir</span><span class="mono">${dns_vultr_snapshot_dir}</span></div>
    <div class="stat"><span class="label">manifest</span><span class="mono">${dns_vultr_manifest_path}</span></div>
    <div class="stat"><span class="label">dump output root</span><span class="mono">${dns_vultr_output_dir}</span></div>
    <div class="stat"><span class="label">recommended command</span><span class="mono">find /var/backups/openbsd-self-hosting/mailstack -path '*/dns/vultr-dump/*/_manifest.json' -type f | tail -1; doas /usr/local/sbin/vultr-restore-from-dump.sh -n -v -i &lt;dumpdir&gt;</span></div>
  </article>
</section>

<section class="card" style="margin-top:12px;">
  <h2>managed domains</h2>
  <div class="stat"><span class="label">domain list</span><span class="mono">${dns_domain_names}</span></div>
  <table class="table dns-domain-table">
    <tr><th>domain</th><th>records</th><th>type counts</th><th>artifacts</th></tr>
    ${dns_domain_rows}
  </table>
  <p class="note">Artifacts are stored relative to <span class="mono">${dns_vultr_snapshot_dir}</span>. Each domain keeps an exact-restore <span class="mono">*-records.json</span> snapshot plus a compatibility <span class="mono">*-hosts.xml</span> export inside the nightly Phase 10 mailstack backup.</p>
</section>
EOF

suricata_service_state="warn"
case "$(printf '%s' "${suricata_status_raw}" | tr '[:upper:]' '[:lower:]')" in
  running|enabled|healthy|ok) suricata_service_state="ok" ;;
  stopped|stop|down|error|failed|fail|dead) suricata_service_state="fail" ;;
  *) suricata_service_state="warn" ;;
esac

ids_data_state="ok"
if [ "${suricata_age_min}" -lt 0 ] || [ "${suricata_trend_age_min}" -lt 0 ]; then
  ids_data_state="fail"
elif [ "${suricata_age_min}" -gt 60 ] || [ "${suricata_trend_age_min}" -gt 120 ]; then
  ids_data_state="fail"
elif [ "${suricata_age_min}" -gt 20 ] || [ "${suricata_trend_age_min}" -gt 45 ]; then
  ids_data_state="warn"
fi

ids_alert_state="ok"
if [ "${suricata_alerts_1h}" -ge 120 ] || [ "${suricata_alerts_24h}" -ge 1200 ]; then
  ids_alert_state="fail"
elif [ "${suricata_alerts_1h}" -ge 40 ] || [ "${suricata_alerts_24h}" -ge 400 ]; then
  ids_alert_state="warn"
fi

ids_blocked_state="ok"
if [ "${suricata_blocked_sample_count}" -ge 80 ]; then
  ids_blocked_state="fail"
elif [ "${suricata_blocked_sample_count}" -ge 20 ]; then
  ids_blocked_state="warn"
fi

ids_pf_sync_state="ok"
if [ "${suricata_mode_block_cron}" -ne 1 ]; then
  ids_pf_sync_state="fail"
elif [ "${suricata_eve2pf_candidates}" -gt 0 ] && [ "${table_suricata_block}" -eq 0 ]; then
  ids_pf_sync_state="fail"
elif [ "${suricata_eve2pf_log_age_min}" -lt 0 ] || [ "${suricata_eve2pf_log_age_min}" -gt 20 ]; then
  ids_pf_sync_state="warn"
elif [ "${suricata_eve2pf_candidates}" -gt 0 ] && [ "${table_suricata_block}" -lt "${suricata_eve2pf_candidates}" ]; then
  ids_pf_sync_state="warn"
fi

ids_critical_count=0
ids_warn_count=0
for ids_state in "${suricata_service_state}" "${ids_data_state}" "${ids_alert_state}" "${ids_blocked_state}" "${ids_pf_sync_state}"; do
  case "${ids_state}" in
    fail) ids_critical_count=$((ids_critical_count + 1)) ;;
    warn) ids_warn_count=$((ids_warn_count + 1)) ;;
  esac
done

suricata_service_chip="$(status_chip "${suricata_service_state}")"
ids_data_chip="$(status_chip "${ids_data_state}")"
ids_alert_chip="$(status_chip "${ids_alert_state}")"
ids_blocked_chip="$(status_chip "${ids_blocked_state}")"
ids_pf_sync_chip="$(status_chip "${ids_pf_sync_state}")"

suricata_event_types_items="$(list_items_from_delim "${suricata_event_types_top_raw}" single "no event-type totals in snapshot")"
suricata_protocol_items="$(list_items_from_delim "${suricata_protocol_top_raw}" single "no protocol breakdown in snapshot")"
suricata_action_items="$(list_items_from_delim "${suricata_action_top_raw}" single "no action breakdown in snapshot")"
suricata_keyword_items="$(list_items_from_delim "${suricata_keywords_top_raw}" single "no keyword hit summaries in snapshot")"
suricata_signature_items="$(list_items_from_delim "${suricata_top_signatures_text_raw}" single "no signature samples in snapshot")"
suricata_source_items="$(list_items_from_delim "${suricata_top_sources_text_raw}" single "no source samples in snapshot")"
suricata_recent_blocked_items="$(list_items_from_delim "${suricata_recent_blocked_raw}" double "no blocked events in current sample window")"
suricata_recent_alert_items="$(list_items_from_delim "${suricata_recent_alerts_raw}" double "no alert events in current sample window")"

render_page "${SITE_ROOT}/ids.html" "suricata ids" <<EOF
<section class="grid">
  <article class="card">
    <h2>service function</h2>
    <div class="kpi">${suricata_service_chip}</div>
    <div class="stat"><span class="label">suricata status</span><span class="mono">${suricata_status}</span></div>
    <div class="stat"><span class="label">version</span><span class="mono">${suricata_version}</span></div>
    <div class="stat"><span class="label">log directory</span><span class="mono">${suricata_log_dir}</span></div>
    <div class="stat"><span class="label">snapshot freshness</span><span>${ids_data_chip}</span></div>
    <div class="stat"><span class="label">summary age / trend age</span><span>${suricata_age_min}m / ${suricata_trend_age_min}m</span></div>
  </article>
  <article class="card">
    <h2>threat rollup</h2>
    <div class="stat"><span class="label">total events (window)</span><span>${suricata_event_total}</span></div>
    <div class="stat"><span class="label">alert events (window)</span><span>${suricata_alerts}</span></div>
    <div class="stat"><span class="label">alerts (last hour / 24h)</span><span>${suricata_alerts_1h} / ${suricata_alerts_24h}</span></div>
    <div class="stat"><span class="label">blocked totals</span><span>${suricata_blocked_totals}</span></div>
    <div class="stat"><span class="label">blocked sample / alert sample</span><span>${suricata_blocked_sample_count} / ${suricata_alert_sample_count}</span></div>
    <div class="stat"><span class="label">drops 24h</span><span>$(kv_get "${latest}" suricata_drops_24h 0)</span></div>
    <div class="stat"><span class="label">top blocked signature</span><span class="mono">${suricata_top_blocked_sig}</span></div>
    <div class="stat"><span class="label">top blocked source</span><span class="mono">${suricata_top_source_ip} (${suricata_top_source_hits})</span></div>
    <div class="stat"><span class="label">last blocked timestamp</span><span class="mono">${suricata_last_blocked_ts}</span></div>
  </article>
  <article class="card">
    <h2>pf enforcement context</h2>
    <div class="stat"><span class="label">table suricata_watch</span><span>${table_suricata_watch}</span></div>
    <div class="stat"><span class="label">table suricata_block</span><span>${table_suricata_block}</span></div>
    <div class="stat"><span class="label">table suricata_allow</span><span>${table_suricata_allow}</span></div>
    <div class="stat"><span class="label">eve2pf mode / table</span><span class="mono">${suricata_eve2pf_mode} / ${suricata_eve2pf_table}</span></div>
    <div class="stat"><span class="label">eve2pf candidates / window</span><span>${suricata_eve2pf_candidates} / ${suricata_eve2pf_window_s}s</span></div>
    <div class="stat"><span class="label">eve2pf log age / last run</span><span>${suricata_eve2pf_log_age_min}m / <span class="mono">${suricata_eve2pf_last_ts}</span></span></div>
    <div class="stat"><span class="label">pf sync health</span><span>${ids_pf_sync_chip}</span></div>
    <div class="stat"><span class="label">incident controls fail / warn</span><span>${ids_critical_count} / ${ids_warn_count}</span></div>
    <div class="note">reference view: <a href="/pf/suricata.html">/pf/suricata.html</a></div>
  </article>
</section>

<section class="grid" style="margin-top:12px;">
  <article class="card">
    <h2>event type breakdown</h2>
    <ul class="list">${suricata_event_types_items}</ul>
  </article>
  <article class="card">
    <h2>protocol breakdown</h2>
    <ul class="list">${suricata_protocol_items}</ul>
  </article>
  <article class="card">
    <h2>action breakdown</h2>
    <ul class="list">${suricata_action_items}</ul>
  </article>
  <article class="card">
    <h2>keyword highlights</h2>
    <ul class="list">${suricata_keyword_items}</ul>
  </article>
</section>

<section class="grid" style="margin-top:12px;">
  <article class="card">
    <h2>top signatures</h2>
    <ul class="list">${suricata_signature_items}</ul>
  </article>
  <article class="card">
    <h2>top sources</h2>
    <ul class="list">${suricata_source_items}</ul>
    <p class="note">Trusted LAN sources in <span class="mono">192.168.1.0/24</span> are suppressed here unless they also show blocked-source evidence.</p>
  </article>
</section>

<section class="card" style="margin-top:12px;">
  <h2>incident candidates for automation</h2>
  <table class="table">
    <tr><th>ticket key</th><th>severity</th><th>trigger</th><th>evidence</th><th>remediation / runbook</th></tr>
    <tr>
      <td class="mono">ids-suricata-service</td>
      <td>${suricata_service_chip}</td>
      <td>suricata daemon state should be running</td>
      <td>status=${suricata_status}; version=${suricata_version}; data_age=${suricata_age_min}m</td>
      <td><span class="mono">rcctl check suricata</span>; inspect <span class="mono">${suricata_log_dir}/suricata.log</span>; verify capture interface configuration</td>
    </tr>
    <tr>
      <td class="mono">ids-data-freshness</td>
      <td>${ids_data_chip}</td>
      <td>suricata summary/trend freshness thresholds: warn&gt;20m, fail&gt;60m</td>
      <td>summary_age=${suricata_age_min}m trend_age=${suricata_trend_age_min}m</td>
      <td>check cron/collector execution, validate <span class="mono">${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}/suricata-summary.json</span> update cadence, then rerender monitor</td>
    </tr>
    <tr>
      <td class="mono">ids-alert-volume</td>
      <td>${ids_alert_chip}</td>
      <td>alert thresholds: warn if 1h&gt;=40 or 24h&gt;=400, fail if 1h&gt;=120 or 24h&gt;=1200</td>
      <td>alerts_1h=${suricata_alerts_1h} alerts_24h=${suricata_alerts_24h} sample_alerts=${suricata_alert_sample_count}</td>
      <td>pivot by signature/source below, cross-check <span class="mono">/var/log/suricata/eve.json*</span>, escalate if sustained across two consecutive runs</td>
    </tr>
    <tr>
      <td class="mono">ids-blocked-activity</td>
      <td>${ids_blocked_chip}</td>
      <td>blocked sample thresholds: warn&gt;=20, fail&gt;=80 events in current sample</td>
      <td>blocked_sample=${suricata_blocked_sample_count} blocked_totals=${suricata_blocked_totals} top_sig=${suricata_top_blocked_sig}</td>
      <td>review blocked event samples; confirm expected noisy scanners vs targeted activity; update block/allow policy if justified</td>
    </tr>
    <tr>
      <td class="mono">ids-pf-sync</td>
      <td>${ids_pf_sync_chip}</td>
      <td>recent eve2pf candidates should correlate with PF block table entries</td>
      <td>table_watch=${table_suricata_watch} table_block=${table_suricata_block} table_allow=${table_suricata_allow}; eve2pf_mode=${suricata_eve2pf_mode}; candidates=${suricata_eve2pf_candidates}; window=${suricata_eve2pf_window_s}s; log_age=${suricata_eve2pf_log_age_min}m</td>
      <td>inspect <span class="mono">/var/log/suricata_eve2pf.log</span>, run <span class="mono">MODE=block /usr/local/libexec/suricata/suricata_eve2pf.ksh</span>, then validate PF tables and anchors</td>
    </tr>
  </table>
  <p class="note">Ticket keys are stable identifiers intended for AI/automation pipelines that open, deduplicate, and close incidents based on dashboard state transitions.</p>
</section>

<section class="grid-2" style="margin-top:12px;">
  <article class="card">
    <h2>blocked event samples</h2>
    <ul class="list">${suricata_recent_blocked_items}</ul>
  </article>
  <article class="card">
    <h2>recent alert samples</h2>
    <ul class="list">${suricata_recent_alert_items}</ul>
  </article>
</section>

<section class="card" style="margin-top:12px;">
  <h2>suricata alerts trend (48h from eve history)</h2>
  <img class="trend-lg" src="sparklines/suricata_alerts_48h.svg" alt="suricata alerts 48h trend">
  <div class="stat"><span class="label">latest hour</span><span>${suricata_alerts_1h}</span></div>
  <div class="stat"><span class="label">trend data age</span><span>${suricata_trend_age_min} min</span></div>
  <div class="note">derived from <span class="mono">/var/log/suricata/eve.json</span> plus rotated <span class="mono">eve.json*.gz</span>; merged detail source <a href="/pf/suricata.html">/pf/suricata.html</a>.</div>
</section>
EOF

render_page "${SITE_ROOT}/vpn.html" "wireguard vpn" <<EOF
<section class="card">
  <h2>wireguard posture</h2>
  <table class="table">
    <tr><th>metric</th><th>value</th></tr>
    <tr><td>interface present</td><td>${wg_iface_present}</td></tr>
    <tr><td>peer count</td><td>${wg_peer_count}</td></tr>
    <tr><td>active peers (recent handshake)</td><td>${wg_active_peer_count}</td></tr>
    <tr><td>recommended command</td><td class="mono">wg show wg0</td></tr>
  </table>
</section>
EOF

render_page "${SITE_ROOT}/storage.html" "storage" <<EOF
<section class="grid">
  <article class="card">
    <h2>filesystem pressure</h2>
    <div class="stat"><span class="label">root usage</span><span>${root_use_pct}%</span></div>
    <div class="stat"><span class="label">var usage</span><span>${var_use_pct}%</span></div>
    <div class="stat"><span class="label">home usage</span><span>${home_use_pct}%</span></div>
    <div class="stat"><span class="label">root inode</span><span>$(kv_get "${latest}" root_inode_pct 0)%</span></div>
    <div class="stat"><span class="label">var inode</span><span>$(kv_get "${latest}" var_inode_pct 0)%</span></div>
  </article>
</section>
EOF

render_page "${SITE_ROOT}/backups.html" "backups" <<EOF
<section class="card">
  <h2>backup freshness</h2>
  <table class="table">
    <tr><th>metric</th><th>value</th></tr>
    <tr><td>mailstack age</td><td>${backup_mailstack_age_min} min</td></tr>
    <tr><td>mysql age</td><td>${backup_mysql_age_min} min</td></tr>
    <tr><td>mailstack archive</td><td class="mono">${backup_mailstack_latest_path}</td></tr>
    <tr><td>mysql latest</td><td class="mono">${backup_mysql_latest_path}</td></tr>
    <tr><td>dns zone snapshot age</td><td>${dns_backup_age_display}</td></tr>
    <tr><td>dns zone manifest</td><td class="mono">${dns_vultr_manifest_path}</td></tr>
    <tr><td>verify status</td><td>${verify_status}</td></tr>
    <tr><td>recommended command</td><td class="mono">ls -lt /var/backups/openbsd-self-hosting/mailstack /var/backups/openbsd-self-hosting/mysql</td></tr>
  </table>
</section>

<section class="card" style="margin-top:12px;">
  <h2>backup jobs and schedules</h2>
  <table class="table">
    <tr><th>job</th><th>schedule</th><th>command</th></tr>
    ${backup_job_rows}
  </table>
  <p class="note">Jobs are sourced from the active root crontab so schedule drift remains visible on the monitor.</p>
</section>
EOF

render_page "${SITE_ROOT}/agent.html" "phase-14 ops agent" <<EOF
<section class="grid">
  <article class="card">
    <h2>control-plane status</h2>
    <div class="kpi">${agent_behavior_chip}</div>
    <div class="stat"><span class="label">agent mode</span><span>${agent_mode_chip} <span class="mono">${agent_mode_desc_h}</span></span></div>
    <div class="stat"><span class="label">summary updated</span><span class="mono">${agent_updated_iso}</span></div>
    <div class="stat"><span class="label">summary age</span><span>${agent_updated_age_min} min</span></div>
    <div class="stat"><span class="label">summary source</span><span class="mono">${agent_open_source}</span></div>
    <div class="stat"><span class="label">summary consistency</span><span>${agent_summary_consistency_chip} delta ${agent_summary_queue_delta}</span></div>
  </article>
  <article class="card">
    <h2>trust and integrity</h2>
    <div class="stat"><span class="label">upstream trust</span><span>${agent_upstream_trust_chip} <span class="mono">${agent_upstream_trust_state_raw}</span> (${agent_upstream_trust_confidence_pct}%)</span></div>
    <div class="stat"><span class="label">upstream reasons</span><span class="mono">${agent_upstream_trust_reasons}</span></div>
    <div class="stat"><span class="label">policy trust</span><span>${agent_policy_trust_chip} <span class="mono">${agent_policy_trust_state_raw}</span></span></div>
    <div class="stat"><span class="label">execution gate</span><span>${agent_policy_execution_chip} <span class="mono">${agent_policy_execution_gate_raw}</span></span></div>
    <div class="stat"><span class="label">policy reason</span><span class="mono">${agent_policy_trust_reason}</span></div>
    <div class="stat"><span class="label">queue trust mix</span><span>verified=${agent_queue_trust_verified}, degraded=${agent_queue_trust_degraded}, fail_closed=${agent_queue_trust_fail_closed}</span></div>
  </article>
  <article class="card">
    <h2>report-trust governance</h2>
    <div class="stat"><span class="label">state</span><span>${report_trust_ops_chip}</span></div>
    <div class="stat"><span class="label">false_green / advisory</span><span>${report_trust_false_green_count} / ${report_trust_advisory_count}</span></div>
    <div class="stat"><span class="label">reasons</span><span class="mono">${report_trust_reasons}</span></div>
    <div class="stat"><span class="label">ssh drift / runtime</span><span>${ssh_hardening_mismatch_count} / <span class="mono">${ssh_hardening_state}</span></span></div>
    <div class="stat"><span class="label">doas drift / valid / overlay</span><span>${doas_policy_drift} / ${doas_live_valid} / ${doas_automation_overlay_present}</span></div>
    <div class="stat"><span class="label">maint pending / weekly structured</span><span>${syspatch_pending_count} / ${weekly_maintenance_structured_report}</span></div>
    <p class="note">read-only governance only: detects false-green cron evidence and high-risk daemon/config drift without autonomous reloads, restarts, or package apply.</p>
  </article>
  <article class="card">
    <h2>queue behavior</h2>
    <div class="stat"><span class="label">open tickets</span><span>${agent_queue_count}</span></div>
    <div class="stat"><span class="label">fail / warn_or_other</span><span>${agent_queue_fail_count} / ${agent_queue_warn_count}</span></div>
    <div class="stat"><span class="label">oldest open ticket</span><span class="mono">${agent_oldest_ticket_h}</span></div>
    <div class="stat"><span class="label">oldest control</span><span class="mono">${agent_oldest_control_h}</span></div>
    <div class="stat"><span class="label">oldest age</span><span>${agent_queue_oldest_age_min} min</span></div>
    <div class="stat"><span class="label">risk mix</span><span>high_or_critical=${agent_queue_high_risk}, medium=${agent_queue_medium_risk}, low=${agent_queue_low_risk}</span></div>
    <div class="stat"><span class="label">state mix</span><span>ok:${agent_queue_state_executed_ok} fail:${agent_queue_state_executed_fail} assist:${agent_queue_state_assist_review} manual:${agent_queue_state_manual_review} approval:${agent_queue_state_requires_approval} deferred:${agent_queue_state_deferred} other:${agent_queue_state_other}</span></div>
  </article>
  <article class="card">
    <h2>policy gates</h2>
    <div class="stat"><span class="label">default mode</span><span>${agent_default_mode}</span></div>
    <div class="stat"><span class="label">cooldown sec</span><span>${agent_cooldown_sec}</span></div>
    <div class="stat"><span class="label">max auto actions / run</span><span>${agent_max_auto_actions}</span></div>
    <div class="stat"><span class="label">fast path / feed age</span><span>${agent_fast_path_min_interval_sec}s / ${agent_feed_max_age_sec}s</span></div>
    <div class="stat"><span class="label">max open tickets</span><span>${agent_max_open_tickets}</span></div>
    <div class="stat"><span class="label">summary policy counts</span><span>manual=${agent_policy_manual}, assist=${agent_policy_assist}, auto_safe=${agent_policy_auto_safe}</span></div>
    <div class="stat"><span class="label">queue policy counts</span><span>manual=${agent_queue_policy_manual}, assist=${agent_queue_policy_assist}, auto_safe=${agent_queue_policy_auto_safe}</span></div>
  </article>
  <article class="card">
    <h2>emergency handling</h2>
    <div class="stat"><span class="label">emergency open</span><span>${agent_emergency_open}</span></div>
    <div class="stat"><span class="label">urgent / breakglass</span><span>${agent_emergency_urgent} / ${agent_emergency_breakglass}</span></div>
    <div class="stat"><span class="label">approval required</span><span>${agent_approval_required}</span></div>
    <div class="stat"><span class="label">policy / trust holds</span><span>${agent_policy_integrity_holds} / ${agent_upstream_trust_holds}</span></div>
    <div class="stat"><span class="label">refusals / replay suppressed</span><span>${agent_input_refusals} / ${agent_replay_suppressed}</span></div>
    <div class="stat"><span class="label">last fast path</span><span class="mono">${agent_fast_path_last_run_iso}</span></div>
  </article>
  <article class="card span-all">
    <h2>action execution</h2>
    <div class="stat"><span class="label">last run attempted / ok / failed</span><span>${agent_actions_attempted} / ${agent_actions_ok} / ${agent_actions_failed}</span></div>
    <div class="stat"><span class="label">action log total</span><span>${agent_action_total}</span></div>
    <div class="stat"><span class="label">action log last 24h</span><span>${agent_action_24h}</span></div>
    <div class="stat"><span class="label">24h executed_ok / executed_fail</span><span>${agent_action_ok_24h} / ${agent_action_fail_24h}</span></div>
    <div class="stat"><span class="label">latest action ticket</span><span class="mono">${agent_last_action_ticket_h}</span></div>
    <div class="stat"><span class="label">latest action status</span><span class="mono">${agent_last_action_iso_h} ${agent_last_action_state_h}</span></div>
    <p class="note">${agent_action_expectation_note}</p>
  </article>
</section>

<section class="card" style="margin-top:12px;">
  <h2>phase-14 control policy map</h2>
  <table class="table">
    <tr><th>control key</th><th>policy mode</th><th>objective</th></tr>
    ${agent_policy_rows}
  </table>
</section>

<section class="card" style="margin-top:12px;">
  <h2>open queue and remediation candidates</h2>
  <table class="table">
    <tr><th>ticket id</th><th>control key</th><th>severity</th><th>risk</th><th>trust</th><th>emergency</th><th>approval</th><th>policy mode</th><th>action state</th><th>opened (utc)</th><th>open age</th><th>last exec</th><th>runbook action</th><th>execution command</th><th>breakglass runbook</th><th>evidence</th><th>score factors</th></tr>
    ${agent_queue_rows}
  </table>
  <p class="note">This queue includes <span class="mono">manual</span>, <span class="mono">assist</span>, and <span class="mono">auto_safe</span> controls. Execution is additionally gated by source trust and policy integrity, and emergency rows can carry explicit human-approval or break-glass handling.</p>
</section>

<section class="card" style="margin-top:12px;">
  <h2>emergency and approval-gated queue</h2>
  <table class="table">
    <tr><th>ticket id</th><th>control key</th><th>severity</th><th>risk</th><th>trust</th><th>emergency</th><th>approval</th><th>opened (utc)</th><th>open age</th><th>breakglass runbook</th><th>evidence</th></tr>
    ${agent_emergency_rows}
  </table>
</section>

<section class="card" style="margin-top:12px;">
  <h2>recent action execution log</h2>
  <table class="table">
    <tr><th>executed (utc)</th><th>ticket id</th><th>control key</th><th>policy mode</th><th>action state</th><th>rc</th><th>duration</th><th>log path</th></tr>
    ${agent_action_rows}
  </table>
  <p class="note">${agent_action_expectation_note}</p>
</section>

<section class="card" style="margin-top:12px;">
  <h2>phase-14 change cues</h2>
  <ul class="list">${agent_changes}</ul>
  <div class="stat"><span class="label">summary.kv</span><span class="mono">${agent_summary_kv_path}</span></div>
  <div class="stat"><span class="label">summary.json</span><span class="mono">${agent_summary_json_path}</span></div>
  <div class="stat"><span class="label">queue.tsv</span><span class="mono">${agent_queue_tsv_path}</span></div>
  <div class="stat"><span class="label">queue.json</span><span class="mono">${agent_queue_json_path}</span></div>
  <div class="stat"><span class="label">emergency.tsv</span><span class="mono">${agent_emergency_tsv_path}</span></div>
  <div class="stat"><span class="label">emergency.json</span><span class="mono">${agent_emergency_json_path}</span></div>
  <div class="stat"><span class="label">input-refusals.tsv</span><span class="mono">${agent_refusal_tsv_path}</span></div>
  <div class="stat"><span class="label">policy-trust.kv</span><span class="mono">${agent_policy_trust_kv_path}</span></div>
  <div class="stat"><span class="label">policy-trust.json</span><span class="mono">${agent_policy_trust_json_path}</span></div>
  <div class="stat"><span class="label">latest-report.txt</span><span class="mono">${agent_last_report_path}</span></div>
  <div class="stat"><span class="label">action-log.tsv</span><span class="mono">${agent_action_log_path}</span></div>
  <div class="stat"><span class="label">policy.conf</span><span class="mono">${agent_policy_path}</span></div>
  <div class="note">${agent_changes_page_note}</div>
</section>

<section class="card" style="margin-top:12px;">
  <h2>suspect or refused inputs</h2>
  <table class="table">
    <tr><th>seen (utc)</th><th>ticket id</th><th>control key</th><th>reason</th><th>detail</th><th>raw evidence</th></tr>
    ${agent_refusal_rows}
  </table>
</section>
EOF

ticket_timeline_limit="${TICKET_TIMELINE_LIMIT:-240}"
ticket_cutoff_epoch="$(( $(date +%s) - 86400 ))"
ticket_retention_days="${TICKET_RETENTION_DAYS:-90}"
ticket_event_keep="${TICKET_EVENT_KEEP:-50000}"
ticket_dir="${TICKET_DIR:-${DATA_ROOT}/tickets}"
ticket_state_file="${TICKET_STATE_FILE:-${ticket_dir}/ticket_state.kv}"
ticket_events_file="${TICKET_EVENTS_FILE:-${ticket_dir}/ticket_events.tsv}"
ticket_open_file="${TICKET_OPEN_FILE:-${ticket_dir}/open_tickets.tsv}"

mkdir -p "${ticket_dir}"
[ -f "${ticket_state_file}" ] || : > "${ticket_state_file}"
[ -f "${ticket_events_file}" ] || : > "${ticket_events_file}"

# Summary:
#   state_get helper for persistent ticket state.
state_get() {
  typeset _k _d _v
  _k="$1"
  _d="${2:-}"
  [ -r "${ticket_state_file}" ] || { printf '%s\n' "${_d}"; return 0; }
  _v="$(awk -F= -v k="${_k}" '$1==k {sub(/^[^=]*=/, "", $0); print; exit}' "${ticket_state_file}" 2>/dev/null || true)"
  [ -n "${_v}" ] && printf '%s\n' "${_v}" || printf '%s\n' "${_d}"
}

# Summary:
#   state_set helper for persistent ticket state.
state_set() {
  typeset _k _v
  _k="$1"
  _v="$2"
  printf '%s=%s\n' "${_k}" "${_v}" >> "${ticket_state_tmp}"
}

latest_epoch_current="$(to_int "$(kv_get "${latest}" timestamp_epoch 0)")"
latest_iso_current="$(kv_get "${latest}" timestamp_iso "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
latest_stamp_current="$(printf '%s' "${latest_iso_current}" | tr -d ':-' | tr 'TZ' '_' | sed 's/_$//')"
last_processed_epoch="$(to_int "$(state_get last_processed_epoch 0)")"
process_ticket_events=0
[ "${latest_epoch_current}" -gt "${last_processed_epoch}" ] && process_ticket_events=1

ticket_state_tmp="$(mktemp /tmp/obsd-monitor-ticket-state.XXXXXX)"
ticket_event_tmp="$(mktemp /tmp/obsd-monitor-ticket-events.new.XXXXXX)"
ticket_rows_tmp="$(mktemp /tmp/obsd-monitor-ticket-rows.XXXXXX)"
ticket_open_tmp="$(mktemp /tmp/obsd-monitor-open-tickets.XXXXXX)"

open_ticket_rows=""
open_ticket_count=0

# Summary:
#   handle_control_ticket helper.
handle_control_ticket() {
  typeset _ctl_key _ctl_state _ctl_label _ctl_evidence _ctl_action
  typeset _prev_state _ticket_id _opened_epoch _opened_iso _open_age_min
  _ctl_key="$1"
  _ctl_state="$2"
  _ctl_label="$3"
  _ctl_evidence="$4"
  _ctl_action="$5"

  _prev_state="$(state_get "control.${_ctl_key}.state" ok)"
  _ticket_id="$(state_get "control.${_ctl_key}.ticket_id" "")"
  _opened_epoch="$(to_int "$(state_get "control.${_ctl_key}.opened_epoch" 0)")"
  _opened_iso="$(state_get "control.${_ctl_key}.opened_iso" "n/a")"

  if [ "${_ctl_state}" != "ok" ]; then
    if [ "${_prev_state}" = "ok" ] || [ -z "${_ticket_id}" ]; then
      _ticket_id="$(new_ticket_id "${_ctl_key}" "${latest_epoch_current}")"
      _opened_epoch="${latest_epoch_current}"
      _opened_iso="${latest_iso_current}"
      if [ "${process_ticket_events}" -eq 1 ]; then
        emit_ticket_event "${latest_epoch_current}" "${latest_iso_current}" "${_ticket_id}" "incident_opened" "${_ctl_state}" "open" "${_ctl_label} entered ${_ctl_state}" "${_ctl_evidence}" "${_ctl_action}"
      fi
    elif [ "${_prev_state}" != "${_ctl_state}" ]; then
      if [ "${process_ticket_events}" -eq 1 ]; then
        emit_ticket_event "${latest_epoch_current}" "${latest_iso_current}" "${_ticket_id}" "incident_updated" "${_ctl_state}" "open" "${_ctl_label} severity changed ${_prev_state}->${_ctl_state}" "${_ctl_evidence}" "${_ctl_action}"
      fi
    fi

    _open_age_min=0
    if [ "${_opened_epoch}" -gt 0 ] && [ "${latest_epoch_current}" -ge "${_opened_epoch}" ]; then
      _open_age_min=$(( (latest_epoch_current - _opened_epoch) / 60 ))
    fi
    open_ticket_count=$((open_ticket_count + 1))
    open_ticket_rows="${open_ticket_rows}<tr><td class=\"mono\">$(html_escape "${_ticket_id}")</td><td class=\"mono\">$(html_escape "${_ctl_key}")</td><td>$(status_chip "${_ctl_state}")</td><td class=\"mono\">$(html_escape "${_opened_iso}")</td><td>${_open_age_min}m</td><td class=\"mono\">$(html_escape "${_ctl_evidence}")</td><td>$(html_escape "${_ctl_action}")</td></tr>"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${_ticket_id}" "${_ctl_key}" "${_ctl_state}" "${_opened_iso}" "${_open_age_min}" "${_ctl_evidence}" >> "${ticket_open_tmp}"
  else
    if [ "${_prev_state}" != "ok" ] && [ -n "${_ticket_id}" ] && [ "${process_ticket_events}" -eq 1 ]; then
      emit_ticket_event "${latest_epoch_current}" "${latest_iso_current}" "${_ticket_id}" "remediation_verified" "ok" "closed" "${_ctl_label} returned to ok" "${_ctl_evidence}" "${_ctl_action}"
    fi
    _ticket_id=""
    _opened_epoch=0
    _opened_iso="n/a"
  fi

  state_set "control.${_ctl_key}.state" "${_ctl_state}"
  state_set "control.${_ctl_key}.ticket_id" "${_ticket_id}"
  state_set "control.${_ctl_key}.opened_epoch" "${_opened_epoch}"
  state_set "control.${_ctl_key}.opened_iso" "${_opened_iso}"
}

mail_control_evidence="verify=${verify_status_raw};accepted_24h=${mail_accepted_24h};queue=${mail_queue};mailstats_age=${mailstats_age_min}m;maillog_trend_age=${mail_trend_age_min}m"
mail_control_action="postqueue -p; tail -n 200 /var/log/maillog; rcctl check postfix rspamd dovecot"
handle_control_ticket "ops-mail-operational" "${mail_ops_state}" "mail operational control" "${mail_control_evidence}" "${mail_control_action}"

sbom_control_evidence="daily=${sbom_daily_status_raw}/${sbom_daily_age_min}m exit=${sbom_daily_exit_code};weekly=${sbom_weekly_status_raw}/${sbom_weekly_age_min}m exit=${sbom_weekly_exit_code};capability=${sbom_capability_mode_raw};cve_map=${cve_mapping_supported}"
sbom_control_action="cat ${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}/cron-sbom-daily.json; review /var/log/cron-reports/sbom-*.log; run /usr/local/sbin/sbom-daily-scan.ksh; keep inventory-only fallback clearly labeled when CVE mapping is unavailable"
handle_control_ticket "ops-sbom-lifecycle" "${sbom_ops_state}" "sbom lifecycle control" "${sbom_control_evidence}" "${sbom_control_action}"

suricata_control_evidence="status=${suricata_status_raw};mode_block_cron=${suricata_mode_block_cron};suricata_age=${suricata_age_min}m;trend_age=${suricata_trend_age_min}m;blocked=${suricata_blocked_totals}"
suricata_control_action="rcctl check suricata; verify MODE=block cron line; inspect /var/log/suricata/eve.json and ids.html"
handle_control_ticket "ops-suricata-active-block" "${suricata_ops_state}" "suricata active-block control" "${suricata_control_evidence}" "${suricata_control_action}"

pf_control_evidence="pf_enabled=${pf_enabled};suricata_watch=${table_suricata_watch};suricata_block=${table_suricata_block};suricata_allow=${table_suricata_allow};eve2pf_mode=${suricata_eve2pf_mode_raw};eve2pf_candidates=${suricata_eve2pf_candidates};eve2pf_window_s=${suricata_eve2pf_window_s};eve2pf_log_age=${suricata_eve2pf_log_age_min}m"
pf_control_action="pfctl -s info; tail -n 80 /var/log/suricata_eve2pf.log; MODE=block /usr/local/libexec/suricata/suricata_eve2pf.ksh; pfctl -t suricata_block -T show"
handle_control_ticket "ops-pf-reactive-enforcement" "${pf_ops_state}" "pf reactive-enforcement control" "${pf_control_evidence}" "${pf_control_action}"

patch_control_evidence="weekly_4am=${cron_weekly_maintenance_4am};apply_wrapper=${cron_weekly_maintenance_apply_wrapped};post_wrapper=${cron_weekly_maintenance_post_reboot_wrapped};daily_scan=${cron_daily_patch_scan};regression_gate=${cron_regression_gate};weekly_log_age=${weekly_maintenance_log_age_min}m;maint_log_age=${maint_last_log_age_min}m;regression_log_age=${regression_gate_log_age_min}m;pending_reboot_verify=${weekly_maintenance_pending};last_regression_pass=${maint_last_regression_pass}"
patch_control_action="keep wrapped weekly-maintenance apply/post-reboot reports enabled; add daily openbsd-syspatch.ksh --check; gate with maint-run.ksh --apply or regression-test.ksh --run"
handle_control_ticket "ops-patch-weekly-and-daily-scan" "${patch_ops_state}" "patch governance control" "${patch_control_evidence}" "${patch_control_action}"

report_control_evidence="root_mailto_ops=${cron_mailto_ops};html_report_jobs=${cron_html_report_count};reports_last24h=${cron_reports_24h};latest_report_age=${cron_report_latest_age_min}m"
report_control_action="ensure root crontab MAILTO=${MONITORING_PRIMARY_REPORT_EMAIL}; keep cron-html-report wrappers; verify /var/log/cron-reports freshness"
handle_control_ticket "ops-change-catalog-email" "${reporting_ops_state}" "change-catalog reporting control" "${report_control_evidence}" "${report_control_action}"

report_trust_control_evidence="state=${report_trust_state_raw};false_green=${report_trust_false_green_count};advisory=${report_trust_advisory_count};reasons=${report_trust_reasons_raw};ssh_weekly=${ssh_hardening_weekly_status_raw}/${ssh_hardening_weekly_age_min}m;ssh_runtime=${ssh_hardening_state_raw};ssh_mismatch=${ssh_hardening_mismatch_count};doas_weekly=${doas_policy_weekly_status_raw}/${doas_policy_weekly_age_min}m;doas_runtime=${doas_policy_state_raw};doas_valid=${doas_live_valid};doas_drift=${doas_policy_drift};maint_plan=${maint_plan_status_raw};syspatch_pending=${syspatch_pending_count};sbom_daily=${sbom_daily_status_raw};sbom_capability=${sbom_capability_mode_raw};cve_map=${cve_mapping_supported};weekly_structured=${weekly_maintenance_structured_report};weekly_apply=${weekly_maintenance_apply_status_raw}/${weekly_maintenance_apply_age_display};weekly_post=${weekly_maintenance_post_status_raw}/${weekly_maintenance_post_age_display}"
report_trust_control_action="/bin/ksh ${MONITORING_SSH_HARDENING_SCRIPT:-/usr/local/sbin/ssh-hardening-window.ksh} --verify; /bin/ksh ${MONITORING_DOAS_POLICY_SCRIPT:-/usr/local/sbin/openbsd-mailstack-doas-policy-transition} --check; inspect ${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}/cron-*.json and /var/log/weekly-maintenance.log; keep read-only governance control in documented operator review"
handle_control_ticket "ops-report-trust-governance" "${report_trust_ops_state}" "report trust governance control" "${report_trust_control_evidence}" "${report_trust_control_action}"

engineering_request_key="engineering.monitor_signal_refinement_20260309.logged"
engineering_request_logged="$(state_get "${engineering_request_key}" 0)"
if [ "${engineering_request_logged}" = "1" ]; then
  state_set "${engineering_request_key}" "1"
elif [ "${process_ticket_events}" -eq 1 ]; then
  emit_ticket_event "${latest_epoch_current}" "${latest_iso_current}" "eng-monitor-signal-refinement-20260309" "engineering_change_request" "info" "logged" "monitor UX and signal-noise refinement" "pages=agent,changes,backups,ids,network; scope=layout,suppression,backup-jobs,ids-whitelist,network-device-issues" "deploy updated obsd-monitor collect/render scripts and verify live pages"
  state_set "${engineering_request_key}" "1"
fi

if [ "${process_ticket_events}" -eq 1 ]; then
  abs_queue_now="${d_mail_queue#-}"
  if [ "${abs_queue_now}" -ge 3 ]; then
    sev_now="warn"
    [ "${abs_queue_now}" -ge 10 ] && sev_now="fail"
    emit_ticket_event "${latest_epoch_current}" "${latest_iso_current}" "chg-mail-queue-${latest_stamp_current}" "change_ticket" "${sev_now}" "logged" "mail queue depth changed" "delta_mail_queue=${d_mail_queue};current=${mail_queue}" "inspect postqueue and maillog delivery outcomes"
  fi

  abs_acc_now="${d_mail_accepted#-}"
  if [ "${abs_acc_now}" -ge 25 ]; then
    emit_ticket_event "${latest_epoch_current}" "${latest_iso_current}" "chg-mail-throughput-${latest_stamp_current}" "change_ticket" "warn" "logged" "mail throughput shift detected" "delta_mail_accepted=${d_mail_accepted};current=${mail_accepted}" "validate traffic profile and spam-filter posture"
  fi

  if [ "${d_svc_fail}" -ne 0 ]; then
    sev_now="warn"
    [ "${svc_fail}" -gt 2 ] && sev_now="fail"
    emit_ticket_event "${latest_epoch_current}" "${latest_iso_current}" "chg-service-failures-${latest_stamp_current}" "change_ticket" "${sev_now}" "logged" "service failure count changed" "delta_service_failures=${d_svc_fail};current_failures=${svc_fail}" "run rcctl check on failed services and inspect /var/log/messages"
  fi
fi

state_set "last_processed_epoch" "${latest_epoch_current}"
state_set "last_processed_iso" "${latest_iso_current}"
atomic_install 0644 "${ticket_state_tmp}" "${ticket_state_file}"

if [ "${process_ticket_events}" -eq 1 ] && [ -s "${ticket_event_tmp}" ]; then
  ticket_events_append_tmp="$(mktemp /tmp/obsd-monitor-ticket-events.append.XXXXXX)"
  if [ -s "${ticket_events_file}" ]; then
    cat "${ticket_events_file}" "${ticket_event_tmp}" > "${ticket_events_append_tmp}"
  else
    cat "${ticket_event_tmp}" > "${ticket_events_append_tmp}"
  fi
  atomic_install 0644 "${ticket_events_append_tmp}" "${ticket_events_file}"
  rm -f "${ticket_events_append_tmp}"
fi

ticket_min_epoch="$(( $(date +%s) - (ticket_retention_days * 86400) ))"
awk -F'\t' -v min_epoch="${ticket_min_epoch}" 'NF>=9 && ($1+0)>=min_epoch {print}' "${ticket_events_file}" > "${ticket_rows_tmp}" 2>/dev/null || true
if [ -s "${ticket_rows_tmp}" ]; then
  ticket_events_trim_tmp="$(mktemp /tmp/obsd-monitor-ticket-events.trim.XXXXXX)"
  tail -n "${ticket_event_keep}" "${ticket_rows_tmp}" > "${ticket_events_trim_tmp}"
  atomic_install 0644 "${ticket_events_trim_tmp}" "${ticket_events_file}"
  rm -f "${ticket_events_trim_tmp}"
else
  : > "${ticket_events_file}.tmp.$$"
  atomic_install 0644 "${ticket_events_file}.tmp.$$" "${ticket_events_file}"
  rm -f "${ticket_events_file}.tmp.$$"
fi

ticket_visible_tmp="$(mktemp /tmp/obsd-monitor-ticket-events.visible.XXXXXX)"
if [ -s "${ticket_events_file}" ]; then
  awk -F'\t' '
    NF < 9 { next }
    $4 == "change_ticket" && ($7 == "pf state-table shift detected" || $7 == "suricata alert-volume shift detected") { next }
    { print }
  ' "${ticket_events_file}" > "${ticket_visible_tmp}"
else
  : > "${ticket_visible_tmp}"
fi

ticket_event_count=0
ticket_event_24h=0
ticket_incident_opened_24h=0
ticket_incident_updated_24h=0
ticket_incident_24h=0
ticket_remediation_24h=0
ticket_change_24h=0
ticket_engineering_request_24h=0
ticket_other_24h=0
ticket_breakdown_24h=0
if [ -s "${ticket_visible_tmp}" ]; then
  read ticket_event_count ticket_event_24h ticket_incident_opened_24h ticket_incident_updated_24h ticket_remediation_24h ticket_change_24h ticket_engineering_request_24h ticket_other_24h <<EOF_COUNTS
$(awk -F'\t' -v cutoff="${ticket_cutoff_epoch}" '
  NF>=9 {
    total++
    if (($1+0) >= cutoff) {
      window++
      if ($4=="incident_opened") incident_opened++
      else if ($4=="incident_updated") incident_updated++
      else if ($4=="remediation_verified") remediation++
      else if ($4=="change_ticket") change++
      else if ($4=="engineering_change_request") engineering++
      else other++
    }
  }
  END { printf "%d %d %d %d %d %d %d %d\n", total+0, window+0, incident_opened+0, incident_updated+0, remediation+0, change+0, engineering+0, other+0 }
' "${ticket_visible_tmp}")
EOF_COUNTS
fi
ticket_incident_24h=$((ticket_incident_opened_24h + ticket_incident_updated_24h))
ticket_breakdown_24h=$((ticket_incident_24h + ticket_remediation_24h + ticket_change_24h + ticket_engineering_request_24h + ticket_other_24h))

if [ -s "${ticket_visible_tmp}" ]; then
  sort -nr -k1,1 "${ticket_visible_tmp}" | awk -F'\t' -v lim="${ticket_timeline_limit}" '
    NR > lim { next }
    function esc(s) {
      gsub(/&/, "\\&amp;", s)
      gsub(/</, "\\&lt;", s)
      gsub(/>/, "\\&gt;", s)
      gsub(/"/, "\\&quot;", s)
      gsub(/\047/, "\\&#39;", s)
      return s
    }
    function pretty_type(s, out) {
      out = s
      gsub(/_/, " ", out)
      return out
    }
    function detail_html(s, out) {
      out = esc(s)
      gsub(/[;][[:space:]]*/, "<br>", out)
      return out
    }
    {
      sev = tolower($5)
      chip_class = "chip-neutral"
      event_class = "sev-neutral"
      if (sev ~ /(fail|critical|bad)/) {
        chip_class = "chip-bad"
        event_class = "sev-bad"
      } else if (sev ~ /(warn|degraded)/) {
        chip_class = "chip-warn"
        event_class = "sev-warn"
      } else if (sev ~ /(ok|pass|healthy)/) {
        chip_class = "chip-ok"
        event_class = "sev-ok"
      }
      printf "<article class=\"ticket-event %s\">", event_class
      printf "<div class=\"ticket-event-header\"><div class=\"ticket-event-title\">%s</div><div class=\"ticket-event-chips\"><span class=\"chip chip-neutral\">%s</span><span class=\"chip %s\">%s</span></div></div>", esc($7), esc(pretty_type($4)), chip_class, esc($5)
      printf "<div class=\"ticket-meta-grid\">"
      printf "<div class=\"ticket-meta\"><div class=\"ticket-meta-label\">created (utc)</div><div class=\"ticket-meta-value mono\">%s</div></div>", esc($2)
      printf "<div class=\"ticket-meta\"><div class=\"ticket-meta-label\">ticket id</div><div class=\"ticket-meta-value mono\">%s</div></div>", esc($3)
      printf "<div class=\"ticket-meta\"><div class=\"ticket-meta-label\">state</div><div class=\"ticket-meta-value\">%s</div></div>", esc($6)
      printf "</div>"
      printf "<div class=\"ticket-block-grid\">"
      printf "<div class=\"ticket-block ticket-block-wide\"><div class=\"ticket-block-label\">evidence</div><div class=\"ticket-block-value mono\">%s</div></div>", detail_html($8)
      printf "<div class=\"ticket-block ticket-block-wide\"><div class=\"ticket-block-label\">remediation action</div><div class=\"ticket-block-value\">%s</div></div>", detail_html($9)
      printf "</div>"
      printf "</article>\n"
    }
  ' > "${ticket_rows_tmp}"
else
  : > "${ticket_rows_tmp}"
fi

ticket_timeline_rows="$(cat "${ticket_rows_tmp}" 2>/dev/null || true)"
[ -n "${ticket_timeline_rows}" ] || ticket_timeline_rows="<div class=\"ticket-empty\">no ticket events recorded yet</div>"
[ -n "${open_ticket_rows}" ] || open_ticket_rows="<tr><td colspan=\"7\">no open incident tickets</td></tr>"
atomic_install 0644 "${ticket_open_tmp}" "${ticket_open_file}"

rm -f "${ticket_state_tmp}" "${ticket_event_tmp}" "${ticket_rows_tmp}" "${ticket_open_tmp}" "${ticket_visible_tmp}"

render_page "${SITE_ROOT}/changes.html" "change feed" <<EOF
<section class="card">
  <h2>latest deltas</h2>
  <table class="table">
    <tr><th>signal</th><th>delta</th></tr>
    <tr><td>pf states</td><td>${d_pf_states}</td></tr>
    <tr><td>mail queue</td><td>${d_mail_queue}</td></tr>
    <tr><td>mail accepted</td><td>${d_mail_accepted}</td></tr>
    <tr><td>suricata alerts</td><td>${d_suricata_alerts}</td></tr>
    <tr><td>service failures</td><td>${d_svc_fail}</td></tr>
  </table>
</section>
<section class="card" style="margin-top:12px;">
  <h2>interpreted changes</h2>
  <ul class="list">${changes}</ul>
</section>

<section class="card" style="margin-top:12px;">
  <h2>phase-14 actions behavior and changes</h2>
  <div class="stat"><span class="label">agent behavior</span><span>${agent_behavior_chip}</span></div>
  <div class="stat"><span class="label">agent mode / updated</span><span>${agent_mode_chip} <span class="mono">${agent_mode_desc_h}</span> · <span class="mono">${agent_updated_iso}</span> (${agent_updated_age_min}m)</span></div>
  <div class="stat"><span class="label">queue fail / warn / total</span><span>${agent_queue_fail_count} / ${agent_queue_warn_count} / ${agent_queue_count}</span></div>
  <div class="stat"><span class="label">risk mix</span><span>high_or_critical=${agent_queue_high_risk}, medium=${agent_queue_medium_risk}, low=${agent_queue_low_risk}</span></div>
  <div class="stat"><span class="label">summary queue count / source</span><span>${agent_open_tickets} / <span class="mono">${agent_open_source}</span></span></div>
  <div class="stat"><span class="label">upstream trust / policy trust</span><span>${agent_upstream_trust_chip} <span class="mono">${agent_upstream_trust_state_raw}</span> · ${agent_policy_trust_chip} <span class="mono">${agent_policy_trust_state_raw}</span></span></div>
  <div class="stat"><span class="label">emergency / approval / refusals</span><span>${agent_emergency_open} / ${agent_approval_required} / ${agent_input_refusals}</span></div>
  <div class="stat"><span class="label">action outcomes (last run)</span><span>attempted=${agent_actions_attempted}, ok=${agent_actions_ok}, failed=${agent_actions_failed}</span></div>
  <div class="stat"><span class="label">action log 24h</span><span>total=${agent_action_24h}, executed_ok=${agent_action_ok_24h}, executed_fail=${agent_action_fail_24h}</span></div>
  <div class="stat"><span class="label">latest action</span><span class="mono">${agent_last_action_iso_h} ${agent_last_action_state_h} ${agent_last_action_ticket_h}</span></div>
  <p class="note">${agent_action_expectation_note}</p>
  <ul class="list" style="margin-top:8px;">${agent_changes}</ul>
  <table class="table">
    <tr><th>control key</th><th>risk</th><th>trust</th><th>emergency</th><th>approval</th><th>action state</th><th>open age</th><th>runbook action</th></tr>
    ${agent_queue_rows_short}
  </table>
  <div class="note">${agent_changes_page_note}</div>
</section>

<section class="card" style="margin-top:12px;">
  <h2>phase-14 action execution timeline</h2>
  <table class="table">
    <tr><th>executed (utc)</th><th>ticket id</th><th>control key</th><th>policy mode</th><th>action state</th><th>rc</th><th>duration</th><th>log path</th></tr>
    ${agent_action_rows}
  </table>
  <p class="note">newest rows first from <span class="mono">${agent_action_log_path}</span>. review per-action output under <span class="mono">/var/log/ops-agent/actions</span>.</p>
</section>

<section class="card" style="margin-top:12px;">
  <h2>phase-14 emergency and refusal cues</h2>
  <table class="table">
    <tr><th>ticket id</th><th>control key</th><th>severity</th><th>risk</th><th>trust</th><th>emergency</th><th>approval</th><th>opened (utc)</th><th>open age</th><th>breakglass runbook</th><th>evidence</th></tr>
    ${agent_emergency_rows}
  </table>
  <table class="table" style="margin-top:10px;">
    <tr><th>seen (utc)</th><th>ticket id</th><th>control key</th><th>reason</th><th>detail</th><th>raw evidence</th></tr>
    ${agent_refusal_rows}
  </table>
</section>

<section class="card" style="margin-top:12px;">
  <h2>open incident registry</h2>
  <div class="stat"><span class="label">open incident tickets</span><span>${open_ticket_count}</span></div>
  <table class="table">
    <tr><th>ticket id</th><th>control key</th><th>severity</th><th>opened (utc)</th><th>open age</th><th>evidence</th><th>remediation action</th></tr>
    ${open_ticket_rows}
  </table>
  <p class="note">Open incidents persist until their control state returns to <span class="mono">ok</span>, then a <span class="mono">remediation_verified</span> event is recorded and the ticket is closed.</p>
</section>

<section class="card" style="margin-top:12px;">
  <h2>ticket tracking timeline</h2>
  <div class="ticket-kpi-grid">
    <div class="ticket-kpi"><div class="ticket-kpi-label">events total / last 24h</div><div class="ticket-kpi-value">${ticket_event_count} / ${ticket_event_24h}</div></div>
    <div class="ticket-kpi"><div class="ticket-kpi-label">incident opened / updated 24h</div><div class="ticket-kpi-value">${ticket_incident_opened_24h} / ${ticket_incident_updated_24h}</div></div>
    <div class="ticket-kpi"><div class="ticket-kpi-label">remediation verified 24h</div><div class="ticket-kpi-value">${ticket_remediation_24h}</div></div>
    <div class="ticket-kpi"><div class="ticket-kpi-label">change tickets 24h</div><div class="ticket-kpi-value">${ticket_change_24h}</div></div>
    <div class="ticket-kpi"><div class="ticket-kpi-label">engineering requests 24h</div><div class="ticket-kpi-value">${ticket_engineering_request_24h}</div></div>
    <div class="ticket-kpi"><div class="ticket-kpi-label">other event types 24h</div><div class="ticket-kpi-value">${ticket_other_24h}</div></div>
    <div class="ticket-kpi"><div class="ticket-kpi-label">24h tally check</div><div class="ticket-kpi-value">${ticket_breakdown_24h} of ${ticket_event_24h}</div></div>
  </div>
  <div class="ticket-stream">
    ${ticket_timeline_rows}
  </div>
  <p class="note">Timeline is generated from snapshot state transitions and change deltas. Event types: <span class="mono">incident_opened</span>, <span class="mono">incident_updated</span>, <span class="mono">remediation_verified</span>, <span class="mono">change_ticket</span>, and <span class="mono">engineering_change_request</span>. Events are ordered newest to oldest.</p>
</section>
EOF

printf '%s\n' "rendered=${SITE_ROOT}/index.html"
