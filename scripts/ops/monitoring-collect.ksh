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
TREND_DIR="${TREND_DIR:-${DATA_ROOT}/trends}"
TREND_HOURS="${TREND_HOURS:-48}"
TREND_REFRESH_SECS="${TREND_REFRESH_SECS:-1800}"
MAIL_TREND_TSV="${MAIL_TREND_TSV:-${TREND_DIR}/mail_accepted_48h.tsv}"
MAIL_CONNECT_TREND_TSV="${MAIL_CONNECT_TREND_TSV:-${TREND_DIR}/mail_connect_48h.tsv}"
MAIL_REJECT_TREND_TSV="${MAIL_REJECT_TREND_TSV:-${TREND_DIR}/mail_rejected_48h.tsv}"
MAIL_NONCOMPLIANT_METHODS_TSV="${MAIL_NONCOMPLIANT_METHODS_TSV:-${TREND_DIR}/mail_noncompliant_methods_24h.tsv}"
MAIL_CONNECTION_CATALOG_TSV="${MAIL_CONNECTION_CATALOG_TSV:-${TREND_DIR}/mail_connection_catalog.tsv}"
MAIL_CONNECTION_SOURCES_TSV="${MAIL_CONNECTION_SOURCES_TSV:-${TREND_DIR}/mail_connection_sources.tsv}"
MAILLOG_ROTATE_MAX="${MAILLOG_ROTATE_MAX:-60}"
SURICATA_TREND_TSV="${SURICATA_TREND_TSV:-${TREND_DIR}/suricata_alerts_48h.tsv}"
KEEP_COUNT="${KEEP_COUNT:-2016}"
KEEP_DAYS="${KEEP_DAYS:-30}"
WG_IF="${WG_IF:-wg0}"
SYSPATCH_CHECK_CMD="${SYSPATCH_CHECK_CMD:-/usr/local/sbin/openbsd-syspatch.ksh}"
SYSPATCH_CHECK_TIMEOUT_SECS="${SYSPATCH_CHECK_TIMEOUT_SECS:-120}"
SYSPATCH_CHECK_TIMEOUT_GRACE_SECS="${SYSPATCH_CHECK_TIMEOUT_GRACE_SECS:-5}"

PF_JSON_ROOT="${PF_JSON_ROOT:-${MONITORING_PF_JSON_ROOT:-/var/www/htdocs/pf}}"
MAIL_JSON="${MAIL_JSON:-${PF_JSON_ROOT}/mailstats.json}"
SURICATA_JSON="${SURICATA_JSON:-${PF_JSON_ROOT}/suricata-summary.json}"
SURICATA_EVENTS_JSON="${SURICATA_EVENTS_JSON:-${PF_JSON_ROOT}/suricata-events.json}"
VERIFY_JSON="${VERIFY_JSON:-${PF_JSON_ROOT}/verify-mail-services.json}"
PFSTATS_JSON="${PFSTATS_JSON:-${PF_JSON_ROOT}/pfstats.json}"
SSHGUARD_JSON="${SSHGUARD_JSON:-${PF_JSON_ROOT}/sshguard.json}"
BREVO_JSON="${BREVO_JSON:-${PF_JSON_ROOT}/brevo.json}"
MAINT_PLAN_JSON="${MAINT_PLAN_JSON:-${PF_JSON_ROOT}/cron-maint-plan-daily.json}"
WEEKLY_MAINT_APPLY_JSON="${WEEKLY_MAINT_APPLY_JSON:-${PF_JSON_ROOT}/cron-weekly-maintenance-apply.json}"
WEEKLY_MAINT_POST_JSON="${WEEKLY_MAINT_POST_JSON:-${PF_JSON_ROOT}/cron-weekly-maintenance-post-reboot.json}"
SBOM_SCAN_REPORT_JSON="${SBOM_SCAN_REPORT_JSON:-${MONITORING_SBOM_SCAN_REPORT_JSON:-/var/db/openbsd-mailstack/sbom/scan-report.json}}"
PKG_SNAPSHOT_FILE="${PKG_SNAPSHOT_FILE:-/var/db/pkg-info.current.txt}"
WEEKLY_MAINTENANCE_LOG="${WEEKLY_MAINTENANCE_LOG:-/var/log/weekly-maintenance.log}"
SSH_HARDENING_JSON="${SSH_HARDENING_JSON:-${PF_JSON_ROOT}/cron-ssh-hardening-weekly.json}"
DOAS_POLICY_JSON="${DOAS_POLICY_JSON:-${PF_JSON_ROOT}/cron-doas-policy-weekly.json}"
SSH_HARDENING_SCRIPT="${SSH_HARDENING_SCRIPT:-/usr/local/sbin/ssh-hardening-window.ksh}"
DOAS_POLICY_SCRIPT="${DOAS_POLICY_SCRIPT:-}"
DOAS_LIVE_CONF="${DOAS_LIVE_CONF:-/etc/doas.conf}"
SSHD_LIVE_CONF="${SSHD_LIVE_CONF:-/etc/ssh/sshd_config}"
TS_EPOCH="$(date +%s)"
TS_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

KV_TMP="$(mktemp /tmp/obsd-monitor.kv.XXXXXX)"
JSON_TMP="$(mktemp /tmp/obsd-monitor.json.XXXXXX)"

# Summary:
#   cleanup helper.
cleanup() {
  rm -f "${KV_TMP}" "${JSON_TMP}"
}
trap cleanup EXIT HUP INT TERM

# Summary:
#   resolve the doas policy authority for the current host posture.
resolve_doas_policy_script() {
  _live_conf="${DOAS_LIVE_CONF:-/etc/doas.conf}"
  _command_scoped=0

  if [ -r "${_live_conf}" ] && \
    grep -Eq '^[[:space:]]*permit[[:space:]]+nopass[[:space:]]+:wheel[[:space:]]+cmd[[:space:]]+' "${_live_conf}" 2>/dev/null; then
    _command_scoped=1
  fi

  if [ "${_command_scoped}" -eq 1 ]; then
    for _candidate in \
      /usr/local/sbin/openbsd-mailstack-doas-policy-transition \
      ${PROJECT_ROOT}/maint/doas-policy-transition.ksh
    do
      [ -x "${_candidate}" ] || continue
      printf '%s\n' "${_candidate}"
      return 0
    done
  fi

  for _candidate in \
    /usr/local/sbin/openbsd-mailstack-doas-policy-baseline-check \
    ${PROJECT_ROOT}/maint/doas-policy-baseline-check.ksh \
    /usr/local/sbin/openbsd-mailstack-doas-policy-transition \
    ${PROJECT_ROOT}/maint/doas-policy-transition.ksh
  do
    [ -x "${_candidate}" ] || continue
    printf '%s\n' "${_candidate}"
    return 0
  done

  printf '%s\n' "${PROJECT_ROOT}/maint/doas-policy-baseline-check.ksh"
}

[ -n "${DOAS_POLICY_SCRIPT}" ] || DOAS_POLICY_SCRIPT="$(resolve_doas_policy_script)"

# Summary:
#   kv_set helper.
kv_set() {
  key="$1"
  shift
  val="$*"
  val="$(printf '%s' "${val}" | tr '\n' ' ' | tr '\r' ' ' | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')"
  printf '%s=%s\n' "${key}" "${val}" >> "${KV_TMP}"
}

# Summary:
#   num_or_default helper.
num_or_default() {
  v="$1"
  d="$2"
  case "${v}" in
    ''|*[!0-9-]*) printf '%s\n' "${d}" ;;
    *) printf '%s\n' "${v}" ;;
  esac
}

# Summary:
#   json_num_key helper.
json_num_key() {
  f="$1"
  key="$2"
  [ -r "${f}" ] || { printf '0\n'; return 0; }
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "${key}" '.[$k] // 0 | if type=="number" then . else 0 end' "${f}" 2>/dev/null || printf '0\n'
    return 0
  fi
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\\(-\\{0,1\\}[0-9][0-9]*\\).*/\\1/p" "${f}" | head -n 1 | awk '{print $1+0}' || printf '0\n'
}

# Summary:
#   json_string_key helper.
json_string_key() {
  f="$1"
  key="$2"
  [ -r "${f}" ] || { printf 'unknown\n'; return 0; }
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "${key}" '.[$k] // "unknown" | tostring' "${f}" 2>/dev/null || printf 'unknown\n'
    return 0
  fi
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "${f}" | head -n 1 || printf 'unknown\n'
}

# Summary:
#   json_num_path helper.
json_num_path() {
  f="$1"
  expr="$2"
  d="${3:-0}"
  [ -r "${f}" ] || { printf '%s\n' "${d}"; return 0; }
  if command -v jq >/dev/null 2>&1; then
    jq -r "(${expr}) // ${d} | if type==\"number\" then . else ${d} end" "${f}" 2>/dev/null || printf '%s\n' "${d}"
    return 0
  fi
  printf '%s\n' "${d}"
}

# Summary:
#   json_string_path helper.
json_string_path() {
  f="$1"
  expr="$2"
  d="${3:-unknown}"
  [ -r "${f}" ] || { printf '%s\n' "${d}"; return 0; }
  if command -v jq >/dev/null 2>&1; then
    jq -r "(${expr}) // \"${d}\" | tostring" "${f}" 2>/dev/null || printf '%s\n' "${d}"
    return 0
  fi
  printf '%s\n' "${d}"
}

# Summary:
#   file_age_minutes helper.
file_age_minutes() {
  f="$1"
  if [ ! -e "${f}" ]; then
    printf '%s\n' '-1'
    return 0
  fi
  m="$(stat -f %m "${f}" 2>/dev/null || printf '0')"
  m="$(num_or_default "${m}" 0)"
  if [ "${m}" -le 0 ]; then
    printf '%s\n' '-1'
    return 0
  fi
  printf '%s\n' "$(( (TS_EPOCH - m) / 60 ))"
}

# Summary:
#   file_age_seconds helper.
file_age_seconds() {
  f="$1"
  if [ ! -e "${f}" ]; then
    printf '%s\n' '-1'
    return 0
  fi
  m="$(stat -f %m "${f}" 2>/dev/null || printf '0')"
  m="$(num_or_default "${m}" 0)"
  if [ "${m}" -le 0 ]; then
    printf '%s\n' '-1'
    return 0
  fi
  printf '%s\n' "$(( TS_EPOCH - m ))"
}

# Summary:
#   time_to_epoch helper.
time_to_epoch() {
  _t="$1"
  [ -n "${_t}" ] || { printf '0\n'; return 0; }
  if _e="$(date -j -f '%Y-%m-%dT%H:%M:%S%z' "${_t}" '+%s' 2>/dev/null)"; then
    printf '%s\n' "${_e}"
    return 0
  fi
  if _e="$(date -j -f '%Y-%m-%d %H:%M:%S %z' "${_t}" '+%s' 2>/dev/null)"; then
    printf '%s\n' "${_e}"
    return 0
  fi
  printf '0\n'
}

# Summary:
#   parse_syspatch_log_stats helper.
# Output:
#   pending_count<TAB>pending_list<TAB>installed_count
parse_syspatch_log_stats() {
  _f="$1"
  [ -r "${_f}" ] || { printf '0\tnone\t0\n'; return 0; }
  awk '
    /syspatch available patches/ { mode="avail"; next }
    /syspatch installed patches/ { mode="inst"; next }
    $0 ~ /^[0-9][0-9][0-9]_[A-Za-z0-9_.-]+$/ {
      if (mode == "avail") {
        pending++
        if (pending_list != "") pending_list = pending_list " | " $0
        else pending_list = $0
      } else if (mode == "inst") {
        installed++
      }
    }
    END {
      if (pending_list == "") pending_list = "none"
      printf "%d\t%s\t%d\n", pending + 0, pending_list, installed + 0
    }
  ' "${_f}" 2>/dev/null || printf '0\tnone\t0\n'
}

run_live_syspatch_check() {
  _timeout="$(num_or_default "${SYSPATCH_CHECK_TIMEOUT_SECS}" 120)"
  _grace="$(num_or_default "${SYSPATCH_CHECK_TIMEOUT_GRACE_SECS}" 5)"

  if [ -x "${SYSPATCH_CHECK_CMD}" ]; then
    if [ "${_timeout}" -gt 0 ] && command -v timeout >/dev/null 2>&1; then
      timeout -k "${_grace}" "${_timeout}" "${SYSPATCH_CHECK_CMD}" --check 2>&1
    else
      "${SYSPATCH_CHECK_CMD}" --check 2>&1
    fi
    return $?
  fi

  command -v syspatch >/dev/null 2>&1 || return 127
  if [ "${_timeout}" -gt 0 ] && command -v timeout >/dev/null 2>&1; then
    timeout -k "${_grace}" "${_timeout}" syspatch -c 2>&1
  else
    syspatch -c 2>&1
  fi
}

# Summary:
#   parse_weekly_pkg_stats helper.
# Output:
#   run_total<TAB>last_pkg_run_ts<TAB>last_apply_ts<TAB>last_post_verify_ts<TAB>last_post_verify_status
parse_weekly_pkg_stats() {
  _f="$1"
  [ -r "${_f}" ] || { printf '0\tnone\tnone\tnone\tnone\n'; return 0; }
  awk '
    function extract_ts(line,   t) {
      t = line
      sub(/^\[/, "", t)
      sub(/\].*$/, "", t)
      return t
    }
    /running pkg_add -u/ {
      run_total++
      last_run = extract_ts($0)
    }
    /updates applied; scheduling post-reboot verification/ {
      last_apply = extract_ts($0)
    }
    /post-reboot verification ok/ {
      last_post = extract_ts($0)
      last_status = "ok"
    }
    /post-reboot verification failed/ {
      last_post = extract_ts($0)
      last_status = "fail"
    }
    /no post-reboot flag present; exiting/ {
      last_post = extract_ts($0)
      last_status = "no_flag"
    }
    END {
      if (last_run == "") last_run = "none"
      if (last_apply == "") last_apply = "none"
      if (last_post == "") last_post = "none"
      if (last_status == "") last_status = "none"
      printf "%d\t%s\t%s\t%s\t%s\n", run_total + 0, last_run, last_apply, last_post, last_status
    }
  ' "${_f}" 2>/dev/null || printf '0\tnone\tnone\tnone\tnone\n'
}

# Summary:
#   latest_file helper.
latest_file() {
  pattern="$1"
  ls -1t ${pattern} 2>/dev/null | head -n 1 || true
}

join_lines_pipe() {
  _f="$1"
  [ -s "${_f}" ] || {
    printf 'none\n'
    return 0
  }
  awk '
    BEGIN { first = 1 }
    NF {
      if (first == 0) printf " | "
      printf "%s", $0
      first = 0
    }
    END {
      if (first == 1) printf "none"
      printf "\n"
    }
  ' "${_f}" 2>/dev/null || printf 'none\n'
}

normalize_policy_file() {
  _f="$1"
  [ -r "${_f}" ] || return 1
  awk '
    {
      line = $0
      sub(/#.*/, "", line)
      gsub(/[[:space:]]+/, " ", line)
      sub(/^ /, "", line)
      sub(/ $/, "", line)
      if (line != "") print line
    }
  ' "${_f}" 2>/dev/null
}

ssh_hardening_targets() {
  cat <<'TARGETS'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 4
MaxSessions 8
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30
TARGETS
}

collect_ssh_hardening_stats() {
  _effective_tmp="$(mktemp /tmp/obsd-ssh-hardening.XXXXXX)"
  if ! sshd -T > "${_effective_tmp}" 2>/dev/null; then
    rm -f "${_effective_tmp}"
    printf 'fail\t0\tsshd_-T_failed\t0\t0\t0\n'
    return 0
  fi

  _mismatch_count=0
  _mismatch_list=""
  while IFS=' ' read -r _key _value; do
    [ -n "${_key}" ] || continue
    _want="$(printf '%s' "${_key}" | tr '[:upper:]' '[:lower:]')"
    _actual="$(awk -v k="${_want}" '$1 == k { print $2; exit }' "${_effective_tmp}" 2>/dev/null || true)"
    if [ "${_actual}" != "${_value}" ]; then
      _piece="${_want}:${_actual:-missing}->${_value}"
      if [ -n "${_mismatch_list}" ]; then
        _mismatch_list="${_mismatch_list} | ${_piece}"
      else
        _mismatch_list="${_piece}"
      fi
      _mismatch_count=$((_mismatch_count + 1))
    fi
  done <<EOF_TARGETS
$(ssh_hardening_targets)
EOF_TARGETS

  _syntax_ok=1
  sshd -t -f "${SSHD_LIVE_CONF}" >/dev/null 2>&1 || _syntax_ok=0
  _service_ok=1
  rcctl check sshd >/dev/null 2>&1 || _service_ok=0
  _listener_ok="$(netstat -an -f inet -p tcp 2>/dev/null | awk 'toupper($0) ~ /LISTEN/ && $4 ~ /\.22$/ {f=1} END {print f+0}')"

  _state="ok"
  if [ "${_syntax_ok}" -ne 1 ] || [ "${_service_ok}" -ne 1 ]; then
    _state="fail"
  elif [ "${_mismatch_count}" -gt 0 ]; then
    _state="warn"
  fi
  [ -n "${_mismatch_list}" ] || _mismatch_list="none"
  rm -f "${_effective_tmp}"
  printf '%s\t%d\t%s\t%d\t%d\t%d\n' "${_state}" "${_mismatch_count}" "${_mismatch_list}" "${_syntax_ok}" "${_service_ok}" "${_listener_ok}"
}

collect_doas_policy_stats() {
  _expected_tmp="$(mktemp /tmp/obsd-doas-expected.XXXXXX)"
  _live_norm="$(mktemp /tmp/obsd-doas-live.XXXXXX)"
  _expect_norm="$(mktemp /tmp/obsd-doas-expect.XXXXXX)"
  _live_sorted="$(mktemp /tmp/obsd-doas-live.sorted.XXXXXX)"
  _expect_sorted="$(mktemp /tmp/obsd-doas-expect.sorted.XXXXXX)"
  _missing_tmp="$(mktemp /tmp/obsd-doas-missing.XXXXXX)"
  _extra_tmp="$(mktemp /tmp/obsd-doas-extra.XXXXXX)"

  _state="ok"
  _live_valid=0
  _drift=0
  _missing_rules="none"
  _extra_rules="none"

  if [ ! -x "${DOAS_POLICY_SCRIPT}" ]; then
    rm -f "${_expected_tmp}" "${_live_norm}" "${_expect_norm}" "${_live_sorted}" "${_expect_sorted}" "${_missing_tmp}" "${_extra_tmp}"
    printf 'fail\t0\t0\tdoas_policy_script_missing\tnone\n'
    return 0
  fi
  if ! /bin/ksh "${DOAS_POLICY_SCRIPT}" --render > "${_expected_tmp}" 2>/dev/null; then
    rm -f "${_expected_tmp}" "${_live_norm}" "${_expect_norm}" "${_live_sorted}" "${_expect_sorted}" "${_missing_tmp}" "${_extra_tmp}"
    printf 'fail\t0\t0\tdoas_policy_render_failed\tnone\n'
    return 0
  fi
  if [ ! -r "${DOAS_LIVE_CONF}" ]; then
    rm -f "${_expected_tmp}" "${_live_norm}" "${_expect_norm}" "${_live_sorted}" "${_expect_sorted}" "${_missing_tmp}" "${_extra_tmp}"
    printf 'fail\t0\t0\tdoas_live_conf_missing\tnone\n'
    return 0
  fi

  if doas -C "${DOAS_LIVE_CONF}" true >/dev/null 2>&1; then
    _live_valid=1
  fi

  normalize_policy_file "${DOAS_LIVE_CONF}" > "${_live_norm}"
  normalize_policy_file "${_expected_tmp}" > "${_expect_norm}"
  if ! cmp -s "${_live_norm}" "${_expect_norm}"; then
    _drift=1
    sort "${_live_norm}" > "${_live_sorted}"
    sort "${_expect_norm}" > "${_expect_sorted}"
    comm -23 "${_expect_sorted}" "${_live_sorted}" > "${_missing_tmp}" 2>/dev/null || true
    comm -13 "${_expect_sorted}" "${_live_sorted}" > "${_extra_tmp}" 2>/dev/null || true
    _missing_rules="$(join_lines_pipe "${_missing_tmp}")"
    _extra_rules="$(join_lines_pipe "${_extra_tmp}")"
  fi

  if [ "${_live_valid}" -ne 1 ]; then
    _state="fail"
  elif [ "${_drift}" -ne 0 ]; then
    _state="warn"
  fi

  rm -f "${_expected_tmp}" "${_live_norm}" "${_expect_norm}" "${_live_sorted}" "${_expect_sorted}" "${_missing_tmp}" "${_extra_tmp}"
  printf '%s\t%d\t%d\t%s\t%s\n' "${_state}" "${_live_valid}" "${_drift}" "${_missing_rules}" "${_extra_rules}"
}

# Summary:
#   table_count helper.
table_count() {
  t="$1"
  out="$(pfctl -t "${t}" -T show 2>/dev/null || true)"
  if [ -z "${out}" ]; then
    printf '%s\n' '0'
    return 0
  fi
  printf '%s\n' "${out}" | awk 'NF{c++} END{print c+0}'
}

# Summary:
#   kv_to_json helper.
kv_to_json() {
  f="$1"
  awk -F= '
    function esc(s) {
      gsub(/\\/, "\\\\", s)
      gsub(/"/, "\\\"", s)
      gsub(/\t/, "\\t", s)
      return s
    }
    BEGIN {
      print "{"
      first = 1
    }
    {
      key = $1
      $1 = ""
      sub(/^=/, "", $0)
      val = $0

      if (!first) printf(",\n")
      first = 0

      if (val ~ /^-?[0-9]+([.][0-9]+)?$/ || val == "true" || val == "false") {
        printf("  \"%s\": %s", key, val)
      } else {
        printf("  \"%s\": \"%s\"", key, esc(val))
      }
    }
    END {
      print "\n}"
    }
  ' "${f}"
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
#   stream_maillog_history helper.
stream_maillog_history() {
  [ -r /var/log/maillog ] && cat /var/log/maillog || true
  for f in $(ls -1t /var/log/maillog.* 2>/dev/null | head -n "${MAILLOG_ROTATE_MAX}"); do
    case "${f}" in
      *.gz) zcat "${f}" 2>/dev/null || true ;;
      *) [ -r "${f}" ] && cat "${f}" || true ;;
    esac
  done
}

# Summary:
#   maillog_file_count helper.
maillog_file_count() {
  c=0
  [ -r /var/log/maillog ] && c=$((c + 1))
  rotated="$(ls -1t /var/log/maillog.* 2>/dev/null | head -n "${MAILLOG_ROTATE_MAX}" | awk 'NF{n++} END{print n+0}')"
  rotated="$(num_or_default "${rotated}" 0)"
  c=$((c + rotated))
  printf '%s\n' "${c}"
}

# Summary:
#   build_recent_mail_trend helper.
build_recent_mail_trend() {
  out="$1"
  map_tmp="$(mktemp /tmp/obsd-mail-hour-map.XXXXXX)"
  out_tmp="$(mktemp /tmp/obsd-mail-hour-data.XXXXXX)"

  i=$((TREND_HOURS - 1))
  while [ "${i}" -ge 0 ]; do
    t="$(( TS_EPOCH - (i * 3600) ))"
    key="$(date -r "${t}" '+%b_%d_%H' 2>/dev/null || date '+%b_%d_%H')"
    label="$(date -r "${t}" '+%m-%d %H:00' 2>/dev/null || date '+%m-%d %H:00')"
    printf '%s\t%s\t%s\n' "${key}" "${t}" "${label}" >> "${map_tmp}"
    i=$((i - 1))
  done

  stream_maillog_history | awk -F' ' -v mapf="${map_tmp}" '
    BEGIN {
      while ((getline line < mapf) > 0) {
        split(line, a, "\t")
        k = a[1]
        wanted[k] = 1
        epoch[k] = a[2]
        label[k] = a[3]
        order[++n] = k
        counts[k] = 0
      }
      close(mapf)
    }
    $0 ~ /postfix\/(smtp|lmtp|local|pipe)\[[0-9]+\]: .* status=sent/ {
      if (NF < 3) next
      day = $2 + 0
      hh = substr($3, 1, 2)
      if (hh !~ /^[0-9][0-9]$/) next
      key = sprintf("%s_%02d_%s", $1, day, hh)
      if (key in wanted) counts[key]++
    }
    END {
      for (i = 1; i <= n; i++) {
        k = order[i]
        printf "%s\t%s\t%d\n", epoch[k], label[k], counts[k] + 0
      }
    }
  ' > "${out_tmp}"

  atomic_install 0644 "${out_tmp}" "${out}"
  rm -f "${map_tmp}" "${out_tmp}"
}

# Summary:
#   build_recent_mail_connect_trend helper.
build_recent_mail_connect_trend() {
  out="$1"
  map_tmp="$(mktemp /tmp/obsd-mail-connect-hour-map.XXXXXX)"
  out_tmp="$(mktemp /tmp/obsd-mail-connect-hour-data.XXXXXX)"

  i=$((TREND_HOURS - 1))
  while [ "${i}" -ge 0 ]; do
    t="$(( TS_EPOCH - (i * 3600) ))"
    key="$(date -r "${t}" '+%b_%d_%H' 2>/dev/null || date '+%b_%d_%H')"
    label="$(date -r "${t}" '+%m-%d %H:00' 2>/dev/null || date '+%m-%d %H:00')"
    printf '%s\t%s\t%s\n' "${key}" "${t}" "${label}" >> "${map_tmp}"
    i=$((i - 1))
  done

  stream_maillog_history | awk -F' ' -v mapf="${map_tmp}" '
    function mark_hour(   day, hh, key) {
      if (NF < 3) return
      day = $2 + 0
      hh = substr($3, 1, 2)
      if (hh !~ /^[0-9][0-9]$/) return
      key = sprintf("%s_%02d_%s", $1, day, hh)
      if (key in wanted) counts[key]++
    }
    BEGIN {
      while ((getline line < mapf) > 0) {
        split(line, a, "\t")
        k = a[1]
        wanted[k] = 1
        epoch[k] = a[2]
        label[k] = a[3]
        order[++n] = k
        counts[k] = 0
      }
      close(mapf)
    }
    $0 ~ /postfix\/postscreen(\/postscreen)?\[[0-9]+\]: CONNECT from / {
      mark_hour()
      next
    }
    $0 ~ /postfix\/smtpd[^ ]*\[[0-9]+\]: connect from / {
      mark_hour()
      next
    }
    END {
      for (i = 1; i <= n; i++) {
        k = order[i]
        printf "%s\t%s\t%d\n", epoch[k], label[k], counts[k] + 0
      }
    }
  ' > "${out_tmp}"

  atomic_install 0644 "${out_tmp}" "${out}"
  rm -f "${map_tmp}" "${out_tmp}"
}

# Summary:
#   build_recent_mail_rejected_trend helper.
build_recent_mail_rejected_trend() {
  out="$1"
  map_tmp="$(mktemp /tmp/obsd-mail-reject-hour-map.XXXXXX)"
  out_tmp="$(mktemp /tmp/obsd-mail-reject-hour-data.XXXXXX)"

  i=$((TREND_HOURS - 1))
  while [ "${i}" -ge 0 ]; do
    t="$(( TS_EPOCH - (i * 3600) ))"
    key="$(date -r "${t}" '+%b_%d_%H' 2>/dev/null || date '+%b_%d_%H')"
    label="$(date -r "${t}" '+%m-%d %H:00' 2>/dev/null || date '+%m-%d %H:00')"
    printf '%s\t%s\t%s\n' "${key}" "${t}" "${label}" >> "${map_tmp}"
    i=$((i - 1))
  done

  stream_maillog_history | awk -F' ' -v mapf="${map_tmp}" '
    function mark_hour(   day, hh, key) {
      if (NF < 3) return
      day = $2 + 0
      hh = substr($3, 1, 2)
      if (hh !~ /^[0-9][0-9]$/) return
      key = sprintf("%s_%02d_%s", $1, day, hh)
      if (key in wanted) counts[key]++
    }
    BEGIN {
      while ((getline line < mapf) > 0) {
        split(line, a, "\t")
        k = a[1]
        wanted[k] = 1
        epoch[k] = a[2]
        label[k] = a[3]
        order[++n] = k
        counts[k] = 0
      }
      close(mapf)
    }
    $0 ~ /postfix\/smtpd[^ ]*\[[0-9]+\]: .* reject:/ {
      mark_hour()
      next
    }
    $0 ~ /postfix\/postscreen(\/postscreen)?\[[0-9]+\]: .* (PREGREET|NON-SMTP COMMAND|COMMAND TIME LIMIT|BARE NEWLINE|DNSBL rank)/ {
      mark_hour()
      next
    }
    END {
      for (i = 1; i <= n; i++) {
        k = order[i]
        printf "%s\t%s\t%d\n", epoch[k], label[k], counts[k] + 0
      }
    }
  ' > "${out_tmp}"

  atomic_install 0644 "${out_tmp}" "${out}"
  rm -f "${map_tmp}" "${out_tmp}"
}

# Summary:
#   build_mail_noncompliant_method_breakdown helper.
build_mail_noncompliant_method_breakdown() {
  out="$1"
  map_tmp="$(mktemp /tmp/obsd-mail-noncompliant-hour-map.XXXXXX)"
  raw_tmp="$(mktemp /tmp/obsd-mail-noncompliant-methods.raw.XXXXXX)"
  out_tmp="$(mktemp /tmp/obsd-mail-noncompliant-methods.out.XXXXXX)"

  i=23
  while [ "${i}" -ge 0 ]; do
    t="$(( TS_EPOCH - (i * 3600) ))"
    key="$(date -r "${t}" '+%b_%d_%H' 2>/dev/null || date '+%b_%d_%H')"
    printf '%s\n' "${key}" >> "${map_tmp}"
    i=$((i - 1))
  done

  stream_maillog_history | awk -F' ' -v mapf="${map_tmp}" '
    function in_window(   day, hh, key) {
      if (NF < 3) return 0
      day = $2 + 0
      hh = substr($3, 1, 2)
      if (hh !~ /^[0-9][0-9]$/) return 0
      key = sprintf("%s_%02d_%s", $1, day, hh)
      return (key in wanted)
    }
    function add_method(raw,   m) {
      m = raw
      gsub(/^[[:space:]]+/, "", m)
      gsub(/[[:space:]]+$/, "", m)
      sub(/^[^A-Za-z0-9_-]*/, "", m)
      sub(/[[:space:]].*$/, "", m)
      gsub(/[^A-Za-z0-9_-]/, "", m)
      m = toupper(m)
      if (m == "" || m == "UNKNOWN") m = "OTHER"
      counts[m]++
    }
    BEGIN {
      while ((getline line < mapf) > 0) {
        wanted[line] = 1
      }
      close(mapf)
    }
    {
      if (!in_window()) next
    }
    $0 ~ /postfix\/postscreen(\/postscreen)?\[[0-9]+\]: .*NON-SMTP COMMAND/ {
      payload = $0
      sub(/^.*NON-SMTP COMMAND[^:]*:[[:space:]]*/, "", payload)
      add_method(payload)
      next
    }
    $0 ~ /postfix\/postscreen(\/postscreen)?\[[0-9]+\]: .*PREGREET/ {
      payload = $0
      sub(/^.*PREGREET[^:]*:[[:space:]]*/, "", payload)
      add_method(payload)
      next
    }
    $0 ~ /postfix\/postscreen(\/postscreen)?\[[0-9]+\]: .*COMMAND TIME LIMIT/ {
      payload = "COMMAND_TIMEOUT"
      if (match($0, / after [^: ]+/)) {
        payload = substr($0, RSTART + 7, RLENGTH - 7)
      }
      add_method(payload)
      next
    }
    $0 ~ /postfix\/postscreen(\/postscreen)?\[[0-9]+\]: .*BARE NEWLINE/ {
      add_method("BARE_NEWLINE")
      next
    }
    $0 ~ /postfix\/smtpd[^ ]*\[[0-9]+\]: .* reject:/ {
      payload = $0
      sub(/^.* reject:[[:space:]]*/, "", payload)
      add_method(payload)
      next
    }
    END {
      for (m in counts) printf "%s\t%d\n", m, counts[m] + 0
    }
  ' > "${raw_tmp}"

  if [ -s "${raw_tmp}" ]; then
    sort -k2,2nr -k1,1 "${raw_tmp}" | head -n 12 > "${out_tmp}"
  else
    printf 'NO_METHOD\t0\n' > "${out_tmp}"
  fi

  atomic_install 0644 "${out_tmp}" "${out}"
  rm -f "${map_tmp}" "${raw_tmp}" "${out_tmp}"
}

# Summary:
#   build_mail_connection_catalog helper.
build_mail_connection_catalog() {
  out_catalog="$1"
  out_sources="$2"
  raw_catalog_tmp="$(mktemp /tmp/obsd-mail-conn-catalog.raw.XXXXXX)"
  raw_sources_tmp="$(mktemp /tmp/obsd-mail-conn-sources.raw.XXXXXX)"
  out_catalog_tmp="$(mktemp /tmp/obsd-mail-conn-catalog.out.XXXXXX)"
  out_sources_tmp="$(mktemp /tmp/obsd-mail-conn-sources.out.XXXXXX)"

  stream_maillog_history | awk -v outsrc="${raw_sources_tmp}" '
    function source_ip(line,   ip) {
      ip = line
      sub(/^.*\[/, "", ip)
      sub(/\].*$/, "", ip)
      if (ip ~ /^[0-9A-Fa-f:.]+$/) return ip
      return ""
    }
    {
      counts["log_lines_scanned"]++
    }
    $0 ~ /postfix\/postscreen(\/postscreen)?\[[0-9]+\]: CONNECT from / {
      counts["attempt_events_total"]++
      counts["connect_postscreen"]++
      ip = source_ip($0)
      if (ip != "") source_counts[ip]++
      next
    }
    $0 ~ /postfix\/smtpd[^ ]*\[[0-9]+\]: connect from / {
      counts["attempt_events_total"]++
      counts["connect_smtpd"]++
      ip = source_ip($0)
      if (ip != "") source_counts[ip]++
      next
    }
    $0 ~ /postfix\/smtpd[^ ]*\[[0-9]+\]: .* reject:/ {
      counts["reject_smtpd"]++
      counts["rejected_total"]++
      next
    }
    $0 ~ /postfix\/postscreen(\/postscreen)?\[[0-9]+\]: .*PREGREET/ {
      counts["postscreen_pregreet"]++
      counts["noncompliant_total"]++
      next
    }
    $0 ~ /postfix\/postscreen(\/postscreen)?\[[0-9]+\]: .*NON-SMTP COMMAND/ {
      counts["postscreen_non_smtp_command"]++
      counts["noncompliant_total"]++
      next
    }
    $0 ~ /postfix\/postscreen(\/postscreen)?\[[0-9]+\]: .*COMMAND TIME LIMIT/ {
      counts["postscreen_command_timeout"]++
      counts["noncompliant_total"]++
      next
    }
    $0 ~ /postfix\/postscreen(\/postscreen)?\[[0-9]+\]: .*BARE NEWLINE/ {
      counts["postscreen_bare_newline"]++
      counts["noncompliant_total"]++
      next
    }
    $0 ~ /postfix\/postscreen(\/postscreen)?\[[0-9]+\]: .*DNSBL rank/ {
      counts["postscreen_dnsbl_rank"]++
      counts["rejected_total"]++
      next
    }
    $0 ~ /postfix\/smtpd[^ ]*\[[0-9]+\]: .*lost connection/ {
      counts["smtpd_lost_connection"]++
      next
    }
    $0 ~ /postfix\/smtpd[^ ]*\[[0-9]+\]: .*TLS connection established/ || $0 ~ /postfix\/smtpd[^ ]*\[[0-9]+\]: .*TLSv1\./ {
      counts["smtpd_tls_established"]++
      next
    }
    $0 ~ /postfix\/smtpd[^ ]*\[[0-9]+\]: .*SSL_accept error/ || $0 ~ /postfix\/smtpd[^ ]*\[[0-9]+\]: .*TLS library problem/ {
      counts["smtpd_tls_errors"]++
      next
    }
    END {
      if (counts["attempt_events_total"] == 0) counts["attempt_events_total"] = 0
      if (counts["rejected_total"] == 0) counts["rejected_total"] = 0
      if (counts["noncompliant_total"] == 0) counts["noncompliant_total"] = 0
      for (k in counts) printf "%s\t%d\n", k, counts[k] + 0
      for (ip in source_counts) printf "%s\t%d\n", ip, source_counts[ip] + 0 > outsrc
    }
  ' > "${raw_catalog_tmp}"

  if [ -s "${raw_catalog_tmp}" ]; then
    sort -k2,2nr -k1,1 "${raw_catalog_tmp}" > "${out_catalog_tmp}"
  else
    : > "${out_catalog_tmp}"
  fi

  if [ -s "${raw_sources_tmp}" ]; then
    sort -k2,2nr -k1,1 "${raw_sources_tmp}" | head -n 20 > "${out_sources_tmp}"
  else
    printf 'NO_SOURCE\t0\n' > "${out_sources_tmp}"
  fi

  atomic_install 0644 "${out_catalog_tmp}" "${out_catalog}"
  atomic_install 0644 "${out_sources_tmp}" "${out_sources}"
  rm -f "${raw_catalog_tmp}" "${raw_sources_tmp}" "${out_catalog_tmp}" "${out_sources_tmp}"
}

# Summary:
#   build_recent_suricata_trend helper.
build_recent_suricata_trend() {
  out="$1"
  map_tmp="$(mktemp /tmp/obsd-suri-hour-map.XXXXXX)"
  out_tmp="$(mktemp /tmp/obsd-suri-hour-data.XXXXXX)"

  i=$((TREND_HOURS - 1))
  while [ "${i}" -ge 0 ]; do
    t="$(( TS_EPOCH - (i * 3600) ))"
    key="$(date -r "${t}" '+%Y-%m-%dT%H' 2>/dev/null || date '+%Y-%m-%dT%H')"
    label="$(date -r "${t}" '+%m-%d %H:00' 2>/dev/null || date '+%m-%d %H:00')"
    printf '%s\t%s\t%s\n' "${key}" "${t}" "${label}" >> "${map_tmp}"
    i=$((i - 1))
  done

  {
    [ -r /var/log/suricata/eve.json ] && cat /var/log/suricata/eve.json || true
    for f in $(ls -1t /var/log/suricata/eve.json.*.gz 2>/dev/null | head -n 8); do
      zcat "${f}" 2>/dev/null || true
    done
  } | awk -v mapf="${map_tmp}" '
    BEGIN {
      while ((getline line < mapf) > 0) {
        split(line, a, "\t")
        k = a[1]
        wanted[k] = 1
        epoch[k] = a[2]
        label[k] = a[3]
        order[++n] = k
        counts[k] = 0
      }
      close(mapf)
    }
    $0 ~ /"event_type":"alert"/ {
      if (match($0, /"timestamp":"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]/)) {
        stamp = substr($0, RSTART, RLENGTH)
        key = substr(stamp, 14, 13)
        if (key in wanted) counts[key]++
      }
    }
    END {
      for (i = 1; i <= n; i++) {
        k = order[i]
        printf "%s\t%s\t%d\n", epoch[k], label[k], counts[k] + 0
      }
    }
  ' > "${out_tmp}"

  atomic_install 0644 "${out_tmp}" "${out}"
  rm -f "${map_tmp}" "${out_tmp}"
}

# Summary:
#   trend_sum_since helper.
trend_sum_since() {
  f="$1"
  cutoff="$2"
  [ -r "${f}" ] || { printf '0\n'; return 0; }
  awk -F'\t' -v c="${cutoff}" '$1+0 >= c+0 { s += $3+0 } END { print s+0 }' "${f}" 2>/dev/null || printf '0\n'
}

# Summary:
#   trend_last_value helper.
trend_last_value() {
  f="$1"
  [ -r "${f}" ] || { printf '0\n'; return 0; }
  awk -F'\t' 'END { print $3+0 }' "${f}" 2>/dev/null || printf '0\n'
}

# Summary:
#   tsv_sum_column helper.
tsv_sum_column() {
  f="$1"
  col="$2"
  [ -r "${f}" ] || { printf '0\n'; return 0; }
  awk -F'\t' -v c="${col}" 'NF >= c { s += $(c)+0 } END { print s+0 }' "${f}" 2>/dev/null || printf '0\n'
}

# Summary:
#   tsv_top_pairs helper.
tsv_top_pairs() {
  f="$1"
  limit="${2:-8}"
  [ -r "${f}" ] || { printf 'none\n'; return 0; }
  out="$(awk -F'\t' -v lim="${limit}" 'NR <= lim && NF >= 2 { if (o != "") o = o " | "; o = o $1 ":" ($2+0) } END { print o }' "${f}" 2>/dev/null || true)"
  [ -n "${out}" ] || out="none"
  printf '%s\n' "${out}"
}

# Summary:
#   tsv_value_by_key helper.
tsv_value_by_key() {
  f="$1"
  key="$2"
  d="${3:-0}"
  [ -r "${f}" ] || { printf '%s\n' "${d}"; return 0; }
  awk -F'\t' -v k="${key}" -v def="${d}" '
    $1 == k { print $2+0; found=1; exit }
    END { if (!found) print def+0 }
  ' "${f}" 2>/dev/null || printf '%s\n' "${d}"
}

mkdir -p "${SNAP_DIR}" "${TREND_DIR}" "${DATA_ROOT}"

hostname_detected="$(hostname 2>/dev/null || echo unknown)"

uptime_line="$(uptime 2>/dev/null || true)"
load_triplet="$(printf '%s\n' "${uptime_line}" | sed -n 's/.*load averages:[[:space:]]*//p' | tr -d ',')"
load_1="$(printf '%s\n' "${load_triplet}" | awk '{print $1}')"
load_5="$(printf '%s\n' "${load_triplet}" | awk '{print $2}')"
load_15="$(printf '%s\n' "${load_triplet}" | awk '{print $3}')"

vm_line="$(vmstat 2>/dev/null | awk 'NR==3 {print; exit}' || true)"
cpu_user_pct="$(printf '%s\n' "${vm_line}" | awk '{if (NF>=3) print $(NF-2); else print 0}')"
cpu_sys_pct="$(printf '%s\n' "${vm_line}" | awk '{if (NF>=2) print $(NF-1); else print 0}')"
cpu_idle_pct="$(printf '%s\n' "${vm_line}" | awk '{if (NF>=1) print $NF; else print 0}')"
mem_avm="$(printf '%s\n' "${vm_line}" | awk '{if (NF>=3) print $3; else print "0"}')"
mem_free="$(printf '%s\n' "${vm_line}" | awk '{if (NF>=4) print $4; else print "0"}')"

root_use_pct="$(df -h 2>/dev/null | awk '$NF=="/" {gsub("%", "", $5); print $5; exit}')"
var_use_pct="$(df -h 2>/dev/null | awk '$NF=="/var" {gsub("%", "", $5); print $5; exit}')"
home_use_pct="$(df -h 2>/dev/null | awk '$NF=="/home" {gsub("%", "", $5); print $5; exit}')"
root_inode_pct="$(df -i 2>/dev/null | awk '$NF=="/" {gsub("%", "", $(NF-1)); print $(NF-1); exit}')"
var_inode_pct="$(df -i 2>/dev/null | awk '$NF=="/var" {gsub("%", "", $(NF-1)); print $(NF-1); exit}')"

svc_total=0
svc_ok=0
svc_fail=0
svc_fail_list=""
svc_non_daemon_count=0
svc_non_daemon_list=""
if command -v rcctl >/dev/null 2>&1; then
  for svc in $(rcctl ls on 2>/dev/null); do
    # rcctl "special variables" (for example pf/check_quotas/library_aslr)
    # do not have rc.d scripts and should not be counted as daemon failures.
    if [ ! -x "/etc/rc.d/${svc}" ]; then
      svc_non_daemon_count=$((svc_non_daemon_count + 1))
      if [ -n "${svc_non_daemon_list}" ]; then
        svc_non_daemon_list="${svc_non_daemon_list},${svc}"
      else
        svc_non_daemon_list="${svc}"
      fi
      continue
    fi

    svc_total=$((svc_total + 1))
    if rcctl check "${svc}" >/dev/null 2>&1; then
      svc_ok=$((svc_ok + 1))
    else
      svc_fail=$((svc_fail + 1))
      if [ -n "${svc_fail_list}" ]; then
        svc_fail_list="${svc_fail_list},${svc}"
      else
        svc_fail_list="${svc}"
      fi
    fi
  done
fi

pf_info="$(pfctl -s info 2>/dev/null || true)"
pf_enabled=0
printf '%s\n' "${pf_info}" | grep -qi 'Status: Enabled' && pf_enabled=1 || true
pf_states="$(printf '%s\n' "${pf_info}" | awk '/current entries/ {print $3; exit}')"
pf_tables="$(pfctl -s Tables 2>/dev/null | awk 'NF {c++} END {print c+0}' || true)"
pf_packets_in_pass="$(printf '%s\n' "${pf_info}" | awk '/Packets In/{getline; print $2; exit}')"
pf_packets_in_block="$(printf '%s\n' "${pf_info}" | awk '/Packets In/{getline; getline; print $2; exit}')"
pf_packets_out_pass="$(printf '%s\n' "${pf_info}" | awk '/Packets Out/{getline; print $2; exit}')"
pf_packets_out_block="$(printf '%s\n' "${pf_info}" | awk '/Packets Out/{getline; getline; print $2; exit}')"
pf_synproxy="$(printf '%s\n' "${pf_info}" | awk '/synproxy/ {print $2; exit}')"

table_sshguard="$(table_count sshguard)"
table_smtp_abuse="$(table_count smtp_abuse)"
table_suricata_watch="$(table_count suricata_watch)"
table_suricata_block="$(table_count suricata_block)"
table_suricata_allow="$(table_count suricata_allow)"

tcp_listen_count="$(netstat -an -f inet -p tcp 2>/dev/null | awk 'toupper($0) ~ /LISTEN/ {c++} END {print c+0}')"
udp_listener_count="$(netstat -an -f inet -p udp 2>/dev/null | awk '$1 ~ /^udp/ && $5=="*.*" {c++} END {print c+0}')"
public_tcp_count="$(netstat -an -f inet -p tcp 2>/dev/null | awk 'toupper($0) ~ /LISTEN/ && $4 !~ /^127\.0\.0\.1\./ && $4 !~ /^10\.44\.0\.1\./ {c++} END {print c+0}')"
public_udp_count="$(netstat -an -f inet -p udp 2>/dev/null | awk '$1 ~ /^udp/ && $5=="*.*" && $4 !~ /^127\.0\.0\.1\./ && $4 !~ /^10\.44\.0\.1\./ {c++} END {print c+0}')"
public_tcp_list="$(netstat -an -f inet -p tcp 2>/dev/null | awk 'toupper($0) ~ /LISTEN/ && $4 !~ /^127\.0\.0\.1\./ && $4 !~ /^10\.44\.0\.1\./ {print $4}' | sort -u | tr '\n' ',' | sed 's/,$//')"
public_udp_list="$(netstat -an -f inet -p udp 2>/dev/null | awk '$1 ~ /^udp/ && $5=="*.*" && $4 !~ /^127\.0\.0\.1\./ && $4 !~ /^10\.44\.0\.1\./ {print $4}' | sort -u | tr '\n' ',' | sed 's/,$//')"

mail_accepted="$(json_num_path "${MAIL_JSON}" '.postfix.accepted' 0)"
mail_rejected="$(json_num_path "${MAIL_JSON}" '.postfix.rejected' 0)"
mail_bounced="$(json_num_path "${MAIL_JSON}" '.postfix.bounced' 0)"
mail_deferred="$(json_num_path "${MAIL_JSON}" '.postfix.deferred' 0)"
mail_queue="$(json_num_path "${MAIL_JSON}" '.postfix.queue_active' 0)"
rspamd_reject="$(json_num_path "${MAIL_JSON}" '.rspamd.reject' 0)"
rspamd_add_header="$(json_num_path "${MAIL_JSON}" '.rspamd.add_header' 0)"
rspamd_greylist="$(json_num_path "${MAIL_JSON}" '.rspamd.greylist' 0)"
rspamd_soft_reject="$(json_num_path "${MAIL_JSON}" '.rspamd.soft_reject' 0)"
vt_checks="$(json_num_path "${MAIL_JSON}" '.virustotal.checks' 0)"
vt_errors="$(json_num_path "${MAIL_JSON}" '.virustotal.errors' 0)"

suricata_alerts="$(json_num_path "${SURICATA_JSON}" '.event_totals.alert' 0)"
suricata_blocked_totals="$(json_num_path "${SURICATA_JSON}" '.blocked_totals' 0)"
suricata_drops_24h="$(json_num_path "${SURICATA_JSON}" '.drops_last_24h' 0)"
suricata_top_blocked_sig="$(json_string_path "${SURICATA_JSON}" '.top_blocked_signature.signature' 'none')"
suricata_top_source_ip="$(json_string_path "${SURICATA_JSON}" '.blocked_sources[0].ip' 'none')"
suricata_top_source_hits="$(json_num_path "${SURICATA_JSON}" '.blocked_sources[0].count' 0)"
suricata_last_blocked_ts="$(json_string_path "${SURICATA_JSON}" '.last_blocked_ts' 'none')"
suricata_status="$(json_string_path "${SURICATA_JSON}" '.status' 'unknown')"
suricata_version="$(json_string_path "${SURICATA_JSON}" '.suricata_version' 'unknown')"
suricata_log_dir="$(json_string_path "${SURICATA_JSON}" '.log_dir' '/var/log/suricata')"
suricata_event_total="$(json_num_path "${SURICATA_JSON}" '((.event_totals // {} | to_entries | map((.value // 0) | tonumber) | add) // 0)' 0)"
suricata_event_types_top="$(json_string_path "${SURICATA_JSON}" '((.event_totals // {} | to_entries | sort_by(-(.value // 0)) | .[0:8] | map("\(.key):\(.value)") | join(" | ")))' 'none')"
suricata_protocol_top="$(json_string_path "${SURICATA_JSON}" '((.protocol_breakdown // {} | to_entries | sort_by(-(.value // 0)) | .[0:8] | map("\(.key):\(.value)") | join(" | ")))' 'none')"
suricata_action_top="$(json_string_path "${SURICATA_JSON}" '((.action_breakdown // {} | to_entries | sort_by(-(.value // 0)) | .[0:8] | map("\(.key):\(.value)") | join(" | ")))' 'none')"
suricata_keywords_top="$(json_string_path "${SURICATA_JSON}" '((.keyword_hits // [] | .[0:8] | map("\(.keyword // "keyword"):\(.count // 0)") | join(" | ")))' 'none')"
suricata_top_signatures_text="$(json_string_path "${SURICATA_JSON}" '((.top_signatures // [] | .[0:10] | map("\(.signature // "unknown") [count:\(.count // 0),sev:\(.severity // "n/a")]") | join(" | ")))' 'none')"
suricata_top_sources_text="$(json_string_path "${SURICATA_JSON}" '(
  ((.blocked_sources // []) | map(.ip // "unknown")) as $blocked_ips
  | ((.top_sources // [])
      | map(
          (.ip // "unknown") as $ip
          | select((($ip | test("^192\\.168\\.1\\.")) | not) or (($blocked_ips | index($ip)) != null))
          | "\($ip) [count:\(.count // 0)]"
        )
      | .[0:10]
      | join(" | "))
  | if . == "" then "none" else . end
)' 'none')"

suricata_recent_blocked="none"
suricata_recent_alerts="none"
suricata_blocked_sample_count=0
suricata_alert_sample_count=0
suricata_eve2pf_log="/var/log/suricata_eve2pf.log"
suricata_eve2pf_mode="unknown"
suricata_eve2pf_table="unknown"
suricata_eve2pf_candidates=0
suricata_eve2pf_window_s=0
suricata_eve2pf_last_ts="none"
suricata_eve2pf_log_age_min="$(file_age_minutes "${suricata_eve2pf_log}")"
if [ -r "${SURICATA_EVENTS_JSON}" ] && command -v jq >/dev/null 2>&1; then
  suricata_blocked_sample_count="$(jq -r '[.[] | select((.blocked == true) or ((.action // "" | ascii_downcase) | test("drop|block|reject|deny")) or ((.signature // "" | ascii_downcase) | test("drop|blocked|dshield block")))] | length' "${SURICATA_EVENTS_JSON}" 2>/dev/null || printf '0')"
  suricata_alert_sample_count="$(jq -r '[.[] | select((.event_type // "") == "alert")] | length' "${SURICATA_EVENTS_JSON}" 2>/dev/null || printf '0')"

  suricata_recent_blocked="$(jq -r '[.[] | select((.blocked == true) or ((.action // "" | ascii_downcase) | test("drop|block|reject|deny")) or ((.signature // "" | ascii_downcase) | test("drop|blocked|dshield block")))][0:14] | map("\(.ts // "n/a") action=\(.action // "other") sev=\(.severity // "n/a") src=\(.src_ip // "?"):\(.src_port // "-") dst=\(.dest_ip // "?"):\(.dest_port // "-") sig=\(.signature // "n/a")") | join(" || ")' "${SURICATA_EVENTS_JSON}" 2>/dev/null || printf 'none')"
  [ -n "${suricata_recent_blocked}" ] || suricata_recent_blocked="none"

  suricata_recent_alerts="$(jq -r '[.[] | select((.event_type // "") == "alert")][0:14] | map("\(.ts // "n/a") action=\(.action // "other") sev=\(.severity // "n/a") src=\(.src_ip // "?"):\(.src_port // "-") dst=\(.dest_ip // "?"):\(.dest_port // "-") sig=\(.signature // "n/a")") | join(" || ")' "${SURICATA_EVENTS_JSON}" 2>/dev/null || printf 'none')"
  [ -n "${suricata_recent_alerts}" ] || suricata_recent_alerts="none"
fi

if [ -r "${suricata_eve2pf_log}" ]; then
  suricata_eve2pf_last_line="$(tail -n 400 "${suricata_eve2pf_log}" 2>/dev/null | awk '/ mode=(watch|block) table=[^ ]+ candidates=[0-9]+ window=[0-9]+s$/ {line=$0} END {print line}')"
  if [ -n "${suricata_eve2pf_last_line}" ]; then
    suricata_eve2pf_last_ts="$(printf '%s\n' "${suricata_eve2pf_last_line}" | awk '{print $1}')"
    suricata_eve2pf_mode="$(printf '%s\n' "${suricata_eve2pf_last_line}" | sed -n 's/.* mode=\([^ ]*\).*/\1/p')"
    suricata_eve2pf_table="$(printf '%s\n' "${suricata_eve2pf_last_line}" | sed -n 's/.* table=\([^ ]*\).*/\1/p')"
    suricata_eve2pf_candidates="$(printf '%s\n' "${suricata_eve2pf_last_line}" | sed -n 's/.* candidates=\([0-9][0-9]*\).*/\1/p')"
    suricata_eve2pf_window_s="$(printf '%s\n' "${suricata_eve2pf_last_line}" | sed -n 's/.* window=\([0-9][0-9]*\)s.*/\1/p')"
  fi
fi
suricata_eve2pf_candidates="$(num_or_default "${suricata_eve2pf_candidates}" 0)"
suricata_eve2pf_window_s="$(num_or_default "${suricata_eve2pf_window_s}" 0)"

verify_status="$(json_string_key "${VERIFY_JSON}" status)"
verify_fail="$(json_num_key "${VERIFY_JSON}" fail)"
verify_warn="$(json_num_key "${VERIFY_JSON}" warn)"
verify_public_ports="$(json_string_path "${VERIFY_JSON}" '.public_ports' '')"

if [ -n "${verify_public_ports}" ]; then
  public_tcp_count="$(printf '%s\n' "${verify_public_ports}" | awk '{for (i=1;i<=NF;i++) if ($i ~ /^tcp:/) c++} END{print c+0}')"
  public_udp_count="$(printf '%s\n' "${verify_public_ports}" | awk '{for (i=1;i<=NF;i++) if ($i ~ /^udp:/) c++} END{print c+0}')"
  public_tcp_list="$(printf '%s\n' "${verify_public_ports}" | awk '{for (i=1;i<=NF;i++) if ($i ~ /^tcp:/) {gsub(/^tcp:/,"",$i); if (a!="") a=a","$i; else a=$i}} END{print (a==""?"none":a)}')"
  public_udp_list="$(printf '%s\n' "${verify_public_ports}" | awk '{for (i=1;i<=NF;i++) if ($i ~ /^udp:/) {gsub(/^udp:/,"",$i); if (a!="") a=a","$i; else a=$i}} END{print (a==""?"none":a)}')"
fi

cron_fail_count=0
cron_warn_count=0
cron_fail_jobs=""
cron_warn_jobs=""
cron_fail_context=""
cron_warn_context=""
doas_policy_weekly_status="UNKNOWN"
doas_policy_weekly_age_min="$(file_age_minutes "${DOAS_POLICY_JSON}")"
ssh_hardening_weekly_status="UNKNOWN"
ssh_hardening_weekly_age_min="$(file_age_minutes "${SSH_HARDENING_JSON}")"
for cfile in \
  "${PF_JSON_ROOT}/cron-newsyslog.json" \
  "${PF_JSON_ROOT}/cron-daily.json" \
  "${PF_JSON_ROOT}/cron-weekly.json" \
  "${PF_JSON_ROOT}/cron-monthly.json" \
  "${WEEKLY_MAINT_APPLY_JSON}" \
  "${WEEKLY_MAINT_POST_JSON}" \
  "${PF_JSON_ROOT}/cron-doas-policy-weekly.json" \
  "${PF_JSON_ROOT}/cron-ssh-hardening-weekly.json" \
  "${PF_JSON_ROOT}/cron-sbom-daily.json" \
  "${PF_JSON_ROOT}/cron-sbom-weekly.json"; do
  [ -r "${cfile}" ] || continue
  status="$(json_string_key "${cfile}" status | tr '[:lower:]' '[:upper:]')"
  label="$(basename "${cfile}" .json)"
  exit_code="$(json_num_key "${cfile}" exit_code)"
  run_finished="$(json_string_key "${cfile}" run_finished)"
  log_file="$(json_string_key "${cfile}" log_file)"
  detail="${label}(exit=${exit_code},finished=${run_finished},log=${log_file})"
  case "${status}" in
    FAIL)
      cron_fail_count=$((cron_fail_count + 1))
      [ -n "${cron_fail_jobs}" ] && cron_fail_jobs="${cron_fail_jobs},${label}" || cron_fail_jobs="${label}"
      [ -n "${cron_fail_context}" ] && cron_fail_context="${cron_fail_context} | ${detail}" || cron_fail_context="${detail}"
      ;;
    WARN)
      cron_warn_count=$((cron_warn_count + 1))
      [ -n "${cron_warn_jobs}" ] && cron_warn_jobs="${cron_warn_jobs},${label}" || cron_warn_jobs="${label}"
      [ -n "${cron_warn_context}" ] && cron_warn_context="${cron_warn_context} | ${detail}" || cron_warn_context="${detail}"
      ;;
  esac
done

doas_policy_weekly_status="$(json_string_key "${DOAS_POLICY_JSON}" status | tr '[:lower:]' '[:upper:]')"
ssh_hardening_weekly_status="$(json_string_key "${SSH_HARDENING_JSON}" status | tr '[:lower:]' '[:upper:]')"

sbom_daily_json="${PF_JSON_ROOT}/cron-sbom-daily.json"
sbom_weekly_json="${PF_JSON_ROOT}/cron-sbom-weekly.json"
sbom_daily_status="$(json_string_key "${sbom_daily_json}" status | tr '[:lower:]' '[:upper:]')"
sbom_weekly_status="$(json_string_key "${sbom_weekly_json}" status | tr '[:lower:]' '[:upper:]')"
sbom_daily_exit_code="$(json_num_key "${sbom_daily_json}" exit_code)"
sbom_weekly_exit_code="$(json_num_key "${sbom_weekly_json}" exit_code)"
sbom_daily_age_min="$(file_age_minutes "${sbom_daily_json}")"
sbom_weekly_age_min="$(file_age_minutes "${sbom_weekly_json}")"

maint_plan_status="$(json_string_key "${MAINT_PLAN_JSON}" status | tr '[:lower:]' '[:upper:]')"
maint_plan_exit_code="$(json_num_key "${MAINT_PLAN_JSON}" exit_code)"
maint_plan_age_min="$(file_age_minutes "${MAINT_PLAN_JSON}")"
maint_plan_log_file="$(json_string_key "${MAINT_PLAN_JSON}" log_file)"
[ "${maint_plan_log_file}" = "unknown" ] && maint_plan_log_file=""
weekly_maintenance_apply_status="$(json_string_key "${WEEKLY_MAINT_APPLY_JSON}" status | tr '[:lower:]' '[:upper:]')"
weekly_maintenance_apply_age_min="$(file_age_minutes "${WEEKLY_MAINT_APPLY_JSON}")"
weekly_maintenance_post_status="$(json_string_key "${WEEKLY_MAINT_POST_JSON}" status | tr '[:lower:]' '[:upper:]')"
weekly_maintenance_post_age_min="$(file_age_minutes "${WEEKLY_MAINT_POST_JSON}")"
syspatch_pending_count=0
syspatch_pending_list="none"
syspatch_installed_count=0
syspatch_data_source="maint_plan"
syspatch_check_status="unknown"
syspatch_check_rc=0
if [ -n "${maint_plan_log_file}" ] && [ -r "${maint_plan_log_file}" ]; then
  syspatch_stats="$(parse_syspatch_log_stats "${maint_plan_log_file}")"
  syspatch_pending_count="$(printf '%s\n' "${syspatch_stats}" | awk -F'\t' '{print $1+0}')"
  syspatch_pending_list="$(printf '%s\n' "${syspatch_stats}" | awk -F'\t' '{print $2}')"
  syspatch_installed_count="$(printf '%s\n' "${syspatch_stats}" | awk -F'\t' '{print $3+0}')"
fi

if syspatch_live_output="$(run_live_syspatch_check)"; then
  syspatch_check_rc=0
  syspatch_check_status="ok"
else
  syspatch_check_rc=$?
  if [ "${syspatch_check_rc}" -eq 2 ]; then
    syspatch_check_rc=0
    syspatch_check_status="ok"
  else
    syspatch_check_status="error"
  fi
fi

if [ "${syspatch_check_status}" = "ok" ]; then
  syspatch_live_tmp="$(mktemp /tmp/obsd-monitor-syspatch-live.XXXXXX)"
  printf '%s\n' "${syspatch_live_output}" > "${syspatch_live_tmp}"
  syspatch_live_stats="$(parse_syspatch_log_stats "${syspatch_live_tmp}")"
  rm -f "${syspatch_live_tmp}"
  syspatch_pending_count="$(printf '%s\n' "${syspatch_live_stats}" | awk -F'\t' '{print $1+0}')"
  syspatch_pending_list="$(printf '%s\n' "${syspatch_live_stats}" | awk -F'\t' '{print $2}')"
  syspatch_installed_count="$(printf '%s\n' "${syspatch_live_stats}" | awk -F'\t' '{print $3+0}')"
  syspatch_data_source="live_check"
fi

syspatch_up_to_date=0
[ "${syspatch_pending_count}" -eq 0 ] && syspatch_up_to_date=1

ssh_hardening_stats="$(collect_ssh_hardening_stats)"
ssh_hardening_state="$(printf '%s\n' "${ssh_hardening_stats}" | awk -F'\t' '{print $1}')"
ssh_hardening_mismatch_count="$(printf '%s\n' "${ssh_hardening_stats}" | awk -F'\t' '{print $2+0}')"
ssh_hardening_mismatches="$(printf '%s\n' "${ssh_hardening_stats}" | awk -F'\t' '{print $3}')"
ssh_hardening_syntax_ok="$(printf '%s\n' "${ssh_hardening_stats}" | awk -F'\t' '{print $4+0}')"
ssh_hardening_service_ok="$(printf '%s\n' "${ssh_hardening_stats}" | awk -F'\t' '{print $5+0}')"
ssh_hardening_listener_ok="$(printf '%s\n' "${ssh_hardening_stats}" | awk -F'\t' '{print $6+0}')"

doas_policy_stats="$(collect_doas_policy_stats)"
doas_policy_state="$(printf '%s\n' "${doas_policy_stats}" | awk -F'\t' '{print $1}')"
doas_live_valid="$(printf '%s\n' "${doas_policy_stats}" | awk -F'\t' '{print $2+0}')"
doas_policy_drift="$(printf '%s\n' "${doas_policy_stats}" | awk -F'\t' '{print $3+0}')"
doas_policy_missing_rules="$(printf '%s\n' "${doas_policy_stats}" | awk -F'\t' '{print $4}')"
doas_policy_extra_rules="$(printf '%s\n' "${doas_policy_stats}" | awk -F'\t' '{print $5}')"
doas_automation_overlay_present=0
[ -n "${DOAS_AUTOMATION_OVERLAY:-}" ] && [ -s "${DOAS_AUTOMATION_OVERLAY}" ] && doas_automation_overlay_present=1

root_cron="$(crontab -l 2>/dev/null || true)"
cron_mailto_ops=0
cron_weekly_maintenance_4am=0
cron_weekly_maintenance_apply_wrapped=0
cron_weekly_maintenance_post_reboot_wrapped=0
cron_daily_patch_scan=0
cron_regression_gate=0
suricata_mode_block_cron=0
cron_html_report_count=0

printf '%s\n' "${root_cron}" | grep -Eq "^[[:space:]]*MAILTO=\"?${MONITORING_PRIMARY_REPORT_EMAIL}\"?[[:space:]]*$" && cron_mailto_ops=1 || true
printf '%s\n' "${root_cron}" | grep -Eq '^[[:space:]]*30[[:space:]]+4[[:space:]]+\*[[:space:]]+\*[[:space:]]+0[[:space:]]+.*weekly-maintenance-cron\.ksh[[:space:]]+--apply([[:space:]]|$)' && cron_weekly_maintenance_4am=1 || true
printf '%s\n' "${root_cron}" | awk '!/^[[:space:]]*#/' | grep -Eq 'cron-html-report\.ksh[[:space:]]+--label[[:space:]]+weekly-maintenance-apply[[:space:]]+--[[:space:]]+/usr/local/sbin/weekly-maintenance-cron\.ksh[[:space:]]+--apply([[:space:]]|$)' && cron_weekly_maintenance_apply_wrapped=1 || true
printf '%s\n' "${root_cron}" | awk '!/^[[:space:]]*#/' | grep -Eq 'weekly-maintenance\.post-reboot.*cron-html-report\.ksh[[:space:]]+--label[[:space:]]+weekly-maintenance-post-reboot[[:space:]]+--[[:space:]]+/usr/local/sbin/weekly-maintenance-cron\.ksh[[:space:]]+--post-reboot([[:space:]]|$)' && cron_weekly_maintenance_post_reboot_wrapped=1 || true
printf '%s\n' "${root_cron}" | awk '!/^[[:space:]]*#/' | grep -Eq '(maint-run\.ksh[[:space:]]+--plan|openbsd-syspatch\.ksh[[:space:]]+--check|openbsd-pkg-upgrade\.ksh[[:space:]]+--check)' && cron_daily_patch_scan=1 || true
printf '%s\n' "${root_cron}" | awk '!/^[[:space:]]*#/' | grep -Eq '(maint-run\.ksh[[:space:]]+--apply|regression-test\.ksh[[:space:]]+--run)' && cron_regression_gate=1 || true
printf '%s\n' "${root_cron}" | awk '!/^[[:space:]]*#/' | grep -Eq 'MODE=block[[:space:]]+/usr/local/libexec/suricata/suricata_eve2pf\.ksh' && suricata_mode_block_cron=1 || true
cron_html_report_count="$(printf '%s\n' "${root_cron}" | awk '!/^[[:space:]]*#/ && /cron-html-report\.ksh/ {c++} END {print c+0}')"

cron_reports_24h="$(find /var/log/cron-reports -type f -name '*.log' -mtime -1 2>/dev/null | wc -l | tr -d ' ' || printf '0')"
cron_reports_24h="$(num_or_default "${cron_reports_24h}" 0)"
cron_report_latest="$(latest_file '/var/log/cron-reports/*.log')"
cron_report_latest_age_min="-1"
[ -n "${cron_report_latest}" ] && cron_report_latest_age_min="$(file_age_minutes "${cron_report_latest}")"
weekly_maintenance_structured_report=0
if [ "${cron_weekly_maintenance_apply_wrapped}" -eq 1 ] && [ "${cron_weekly_maintenance_post_reboot_wrapped}" -eq 1 ]; then
  weekly_maintenance_structured_report=1
fi

weekly_maintenance_log="${WEEKLY_MAINTENANCE_LOG}"
maint_last_log="/var/db/openbsd-self-hosting/maint-last.log"
weekly_maintenance_pending_flag="/var/db/openbsd-self-hosting/weekly-maintenance.post-reboot"
regression_gate_log="$(latest_file '/var/log/cron-reports/regression-gate-*.log')"
weekly_maintenance_log_age_min="$(file_age_minutes "${weekly_maintenance_log}")"
maint_last_log_age_min="$(file_age_minutes "${maint_last_log}")"
regression_gate_log_age_min="-1"
[ -n "${regression_gate_log}" ] && regression_gate_log_age_min="$(file_age_minutes "${regression_gate_log}")"
weekly_maintenance_pending=0
[ -f "${weekly_maintenance_pending_flag}" ] && weekly_maintenance_pending=1
maint_last_regression_pass=0
if [ -r "${maint_last_log}" ] && tail -n 500 "${maint_last_log}" 2>/dev/null | grep -Eqi 'regression tests passed|phase12 regression tests:[[:space:]]*PASS'; then
  maint_last_regression_pass=1
elif [ -n "${regression_gate_log}" ] && [ -r "${regression_gate_log}" ] && \
  tail -n 500 "${regression_gate_log}" 2>/dev/null | grep -Eqi 'regression tests passed|phase12 regression tests:[[:space:]]*PASS'; then
  maint_last_regression_pass=1
fi

pkg_upgrade_runs_total=0
pkg_upgrade_last_run_ts="none"
pkg_upgrade_last_apply_ts="none"
pkg_upgrade_last_post_verify_ts="none"
pkg_upgrade_last_post_verify_status="none"
pkg_upgrade_last_run_age_min=-1
pkg_upgrade_last_apply_age_min=-1
pkg_add_u_recent=0
if [ -r "${weekly_maintenance_log}" ]; then
  pkg_stats="$(parse_weekly_pkg_stats "${weekly_maintenance_log}")"
  pkg_upgrade_runs_total="$(printf '%s\n' "${pkg_stats}" | awk -F'\t' '{print $1+0}')"
  pkg_upgrade_last_run_ts="$(printf '%s\n' "${pkg_stats}" | awk -F'\t' '{print $2}')"
  pkg_upgrade_last_apply_ts="$(printf '%s\n' "${pkg_stats}" | awk -F'\t' '{print $3}')"
  pkg_upgrade_last_post_verify_ts="$(printf '%s\n' "${pkg_stats}" | awk -F'\t' '{print $4}')"
  pkg_upgrade_last_post_verify_status="$(printf '%s\n' "${pkg_stats}" | awk -F'\t' '{print $5}')"
fi

pkg_upgrade_last_run_epoch="$(time_to_epoch "${pkg_upgrade_last_run_ts}")"
if [ "${pkg_upgrade_last_run_epoch}" -gt 0 ] && [ "${TS_EPOCH}" -ge "${pkg_upgrade_last_run_epoch}" ]; then
  pkg_upgrade_last_run_age_min="$(( (TS_EPOCH - pkg_upgrade_last_run_epoch) / 60 ))"
fi
pkg_upgrade_last_apply_epoch="$(time_to_epoch "${pkg_upgrade_last_apply_ts}")"
if [ "${pkg_upgrade_last_apply_epoch}" -gt 0 ] && [ "${TS_EPOCH}" -ge "${pkg_upgrade_last_apply_epoch}" ]; then
  pkg_upgrade_last_apply_age_min="$(( (TS_EPOCH - pkg_upgrade_last_apply_epoch) / 60 ))"
fi
if [ "${pkg_upgrade_last_run_age_min}" -ge 0 ] && [ "${pkg_upgrade_last_run_age_min}" -le 10080 ]; then
  pkg_add_u_recent=1
fi

pkg_snapshot_age_min="$(file_age_minutes "${PKG_SNAPSHOT_FILE}")"
pkg_snapshot_count=0
if [ -r "${PKG_SNAPSHOT_FILE}" ]; then
  pkg_snapshot_count="$(awk 'NF{c++} END{print c+0}' "${PKG_SNAPSHOT_FILE}" 2>/dev/null || printf '0')"
  pkg_snapshot_count="$(num_or_default "${pkg_snapshot_count}" 0)"
fi

sbom_report_age_min="$(file_age_minutes "${SBOM_SCAN_REPORT_JSON}")"
sbom_scanner="$(json_string_key "${SBOM_SCAN_REPORT_JSON}" scanner)"
sbom_package_count="$(json_num_key "${SBOM_SCAN_REPORT_JSON}" package_count)"
sbom_severity_critical="$(json_num_path "${SBOM_SCAN_REPORT_JSON}" '.severity_counts.critical' 0)"
sbom_severity_high="$(json_num_path "${SBOM_SCAN_REPORT_JSON}" '.severity_counts.high' 0)"
sbom_severity_medium="$(json_num_path "${SBOM_SCAN_REPORT_JSON}" '.severity_counts.medium' 0)"
sbom_severity_low="$(json_num_path "${SBOM_SCAN_REPORT_JSON}" '.severity_counts.low' 0)"
sbom_severity_unknown="$(json_num_path "${SBOM_SCAN_REPORT_JSON}" '.severity_counts.unknown' 0)"
sbom_exceptions_total="$(json_num_path "${SBOM_SCAN_REPORT_JSON}" '.exceptions.total' 0)"
sbom_exceptions_expired="$(json_num_path "${SBOM_SCAN_REPORT_JSON}" '.exceptions.expired' 0)"
sbom_exceptions_invalid="$(json_num_path "${SBOM_SCAN_REPORT_JSON}" '.exceptions.invalid' 0)"
sbom_vuln_total="$((sbom_severity_critical + sbom_severity_high + sbom_severity_medium + sbom_severity_low + sbom_severity_unknown))"

cve_mapping_supported=1
case "${sbom_scanner}" in
  openbsd-native-fallback|unknown|'')
    cve_mapping_supported=0
    ;;
esac
sbom_capability_mode="mapped"
[ "${cve_mapping_supported}" -ne 1 ] && sbom_capability_mode="inventory_only"
cve_associated_findings="${sbom_vuln_total}"
cve_association_status="none_detected"
cve_summary_note="SBOM severity totals indicate no currently cataloged findings."
if [ "${cve_mapping_supported}" -eq 0 ]; then
  cve_associated_findings=-1
  cve_association_status="unmapped"
  cve_summary_note="Scanner ${sbom_scanner} does not map package findings to CVE identifiers."
elif [ "${sbom_vuln_total}" -gt 0 ]; then
  cve_association_status="detected"
  cve_summary_note="One or more vulnerability findings are present in SBOM severity totals."
fi

report_trust_state="ok"
report_trust_false_green_count=0
report_trust_advisory_count=0
report_trust_reasons="none"
report_trust_reason_list=""
if [ "${ssh_hardening_state}" = "fail" ]; then
  report_trust_reason_list="${report_trust_reason_list}ssh_hardening_runtime_fail "
fi
if [ "${ssh_hardening_mismatch_count}" -gt 0 ]; then
  report_trust_reason_list="${report_trust_reason_list}ssh_hardening_drift "
fi
if [ "${doas_live_valid}" -ne 1 ]; then
  report_trust_reason_list="${report_trust_reason_list}doas_live_invalid "
fi
if [ "${doas_policy_drift}" -ne 0 ]; then
  report_trust_reason_list="${report_trust_reason_list}doas_policy_drift "
fi
if [ "${ssh_hardening_weekly_status}" = "PASS" ] && \
  { [ "${ssh_hardening_mismatch_count}" -gt 0 ] || [ "${ssh_hardening_state}" = "fail" ]; }; then
  report_trust_false_green_count=$((report_trust_false_green_count + 1))
  report_trust_reason_list="${report_trust_reason_list}ssh_hardening_false_pass "
fi
if [ "${doas_policy_weekly_status}" = "PASS" ] && \
  { [ "${doas_live_valid}" -ne 1 ] || [ "${doas_policy_drift}" -ne 0 ]; }; then
  report_trust_false_green_count=$((report_trust_false_green_count + 1))
  report_trust_reason_list="${report_trust_reason_list}doas_policy_false_pass "
fi
if [ "${maint_plan_status}" = "PASS" ] && [ "${syspatch_pending_count}" -gt 0 ]; then
  report_trust_false_green_count=$((report_trust_false_green_count + 1))
  report_trust_reason_list="${report_trust_reason_list}maint_plan_false_pass "
fi
if [ "${weekly_maintenance_structured_report}" -ne 1 ]; then
  report_trust_advisory_count=$((report_trust_advisory_count + 1))
  report_trust_reason_list="${report_trust_reason_list}weekly_maintenance_unstructured "
fi
if [ "${doas_live_valid}" -ne 1 ] || [ "${ssh_hardening_state}" = "fail" ] || [ "${ssh_hardening_mismatch_count}" -gt 0 ] || \
  [ "${doas_policy_drift}" -ne 0 ] || [ "${report_trust_false_green_count}" -gt 0 ]; then
  report_trust_state="fail"
elif [ "${report_trust_advisory_count}" -gt 0 ]; then
  report_trust_state="warn"
fi
report_trust_reasons="$(printf '%s\n' "${report_trust_reason_list}" | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')"
[ -n "${report_trust_reasons}" ] || report_trust_reasons="none"

lifecycle_gap_state="ok"
lifecycle_gap_reasons="none"
if [ "${syspatch_check_status}" = "error" ] || \
  { [ "${syspatch_data_source}" = "maint_plan" ] && { [ "${maint_plan_status}" != "PASS" ] || [ "${maint_plan_age_min}" -lt 0 ] || [ "${maint_plan_age_min}" -gt 1560 ]; }; }; then
  lifecycle_gap_state="fail"
  if [ "${syspatch_check_status}" = "error" ]; then
    lifecycle_gap_reasons="syspatch_live_check_failed"
  else
    lifecycle_gap_reasons="maint-plan stale_or_failed"
  fi
elif [ "${syspatch_pending_count}" -gt 0 ] || [ "${pkg_add_u_recent}" -ne 1 ] || \
  [ "${sbom_report_age_min}" -lt 0 ] || [ "${sbom_report_age_min}" -gt 1560 ] || \
  [ "${sbom_exceptions_expired}" -gt 0 ]; then
  lifecycle_gap_state="warn"
  lifecycle_gap_reasons=""
  [ "${syspatch_pending_count}" -gt 0 ] && lifecycle_gap_reasons="${lifecycle_gap_reasons}syspatch_pending "
  [ "${pkg_add_u_recent}" -ne 1 ] && lifecycle_gap_reasons="${lifecycle_gap_reasons}pkg_add_u_stale "
  if [ "${sbom_report_age_min}" -lt 0 ] || [ "${sbom_report_age_min}" -gt 1560 ]; then
    lifecycle_gap_reasons="${lifecycle_gap_reasons}sbom_report_stale "
  fi
  [ "${sbom_exceptions_expired}" -gt 0 ] && lifecycle_gap_reasons="${lifecycle_gap_reasons}exceptions_expired "
  lifecycle_gap_reasons="$(printf '%s\n' "${lifecycle_gap_reasons}" | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')"
  [ -n "${lifecycle_gap_reasons}" ] || lifecycle_gap_reasons="none"
fi

pfstats_age_min="$(file_age_minutes "${PFSTATS_JSON}")"
mailstats_age_min="$(file_age_minutes "${MAIL_JSON}")"
suricata_age_min="$(file_age_minutes "${SURICATA_JSON}")"
verify_age_min="$(file_age_minutes "${VERIFY_JSON}")"
sshguard_age_min="$(file_age_minutes "${SSHGUARD_JSON}")"
brevo_age_min="$(file_age_minutes "${BREVO_JSON}")"
mail_log_files_scanned="$(maillog_file_count)"

mail_accepted_24h=0
mail_accepted_1h=0
mail_connect_24h=0
mail_connect_1h=0
mail_rejected_24h=0
mail_rejected_1h=0
mail_noncompliant_attempts_24h=0
mail_noncompliant_top_methods="none"
mail_connection_catalog_top="none"
mail_connection_source_top="none"
mail_connection_events_total=0
mail_connection_rejected_total=0
mail_connection_noncompliant_total=0
mail_connection_lines_scanned=0
suricata_alerts_24h=0
suricata_alerts_1h=0

mail_trend_age_sec="$(file_age_seconds "${MAIL_TREND_TSV}")"
if [ ! -s "${MAIL_TREND_TSV}" ] || [ "${mail_trend_age_sec}" -lt 0 ] || [ "${mail_trend_age_sec}" -ge "${TREND_REFRESH_SECS}" ]; then
  build_recent_mail_trend "${MAIL_TREND_TSV}"
fi

mail_connect_trend_age_sec="$(file_age_seconds "${MAIL_CONNECT_TREND_TSV}")"
if [ ! -s "${MAIL_CONNECT_TREND_TSV}" ] || [ "${mail_connect_trend_age_sec}" -lt 0 ] || [ "${mail_connect_trend_age_sec}" -ge "${TREND_REFRESH_SECS}" ]; then
  build_recent_mail_connect_trend "${MAIL_CONNECT_TREND_TSV}"
fi

mail_reject_trend_age_sec="$(file_age_seconds "${MAIL_REJECT_TREND_TSV}")"
if [ ! -s "${MAIL_REJECT_TREND_TSV}" ] || [ "${mail_reject_trend_age_sec}" -lt 0 ] || [ "${mail_reject_trend_age_sec}" -ge "${TREND_REFRESH_SECS}" ]; then
  build_recent_mail_rejected_trend "${MAIL_REJECT_TREND_TSV}"
fi

mail_noncompliant_methods_age_sec="$(file_age_seconds "${MAIL_NONCOMPLIANT_METHODS_TSV}")"
if [ ! -s "${MAIL_NONCOMPLIANT_METHODS_TSV}" ] || [ "${mail_noncompliant_methods_age_sec}" -lt 0 ] || [ "${mail_noncompliant_methods_age_sec}" -ge "${TREND_REFRESH_SECS}" ]; then
  build_mail_noncompliant_method_breakdown "${MAIL_NONCOMPLIANT_METHODS_TSV}"
fi

mail_connection_catalog_age_sec="$(file_age_seconds "${MAIL_CONNECTION_CATALOG_TSV}")"
mail_connection_sources_age_sec="$(file_age_seconds "${MAIL_CONNECTION_SOURCES_TSV}")"
if [ ! -s "${MAIL_CONNECTION_CATALOG_TSV}" ] || [ ! -s "${MAIL_CONNECTION_SOURCES_TSV}" ] || \
  [ "${mail_connection_catalog_age_sec}" -lt 0 ] || [ "${mail_connection_catalog_age_sec}" -ge "${TREND_REFRESH_SECS}" ] || \
  [ "${mail_connection_sources_age_sec}" -lt 0 ] || [ "${mail_connection_sources_age_sec}" -ge "${TREND_REFRESH_SECS}" ]; then
  build_mail_connection_catalog "${MAIL_CONNECTION_CATALOG_TSV}" "${MAIL_CONNECTION_SOURCES_TSV}"
fi

suricata_trend_age_sec="$(file_age_seconds "${SURICATA_TREND_TSV}")"
if [ ! -s "${SURICATA_TREND_TSV}" ] || [ "${suricata_trend_age_sec}" -lt 0 ] || [ "${suricata_trend_age_sec}" -ge "${TREND_REFRESH_SECS}" ]; then
  build_recent_suricata_trend "${SURICATA_TREND_TSV}"
fi

cutoff_24h="$((TS_EPOCH - 86400))"
mail_accepted_24h="$(trend_sum_since "${MAIL_TREND_TSV}" "${cutoff_24h}")"
mail_accepted_1h="$(trend_last_value "${MAIL_TREND_TSV}")"
mail_connect_24h="$(trend_sum_since "${MAIL_CONNECT_TREND_TSV}" "${cutoff_24h}")"
mail_connect_1h="$(trend_last_value "${MAIL_CONNECT_TREND_TSV}")"
mail_rejected_24h="$(trend_sum_since "${MAIL_REJECT_TREND_TSV}" "${cutoff_24h}")"
mail_rejected_1h="$(trend_last_value "${MAIL_REJECT_TREND_TSV}")"
mail_noncompliant_attempts_24h="$(tsv_sum_column "${MAIL_NONCOMPLIANT_METHODS_TSV}" 2)"
mail_noncompliant_top_methods="$(tsv_top_pairs "${MAIL_NONCOMPLIANT_METHODS_TSV}" 8)"
mail_connection_catalog_top="$(tsv_top_pairs "${MAIL_CONNECTION_CATALOG_TSV}" 10)"
mail_connection_source_top="$(tsv_top_pairs "${MAIL_CONNECTION_SOURCES_TSV}" 8)"
mail_connection_events_total="$(tsv_value_by_key "${MAIL_CONNECTION_CATALOG_TSV}" attempt_events_total 0)"
mail_connection_rejected_total="$(tsv_value_by_key "${MAIL_CONNECTION_CATALOG_TSV}" rejected_total 0)"
mail_connection_noncompliant_total="$(tsv_value_by_key "${MAIL_CONNECTION_CATALOG_TSV}" noncompliant_total 0)"
mail_connection_lines_scanned="$(tsv_value_by_key "${MAIL_CONNECTION_CATALOG_TSV}" log_lines_scanned 0)"
suricata_alerts_24h="$(trend_sum_since "${SURICATA_TREND_TSV}" "${cutoff_24h}")"
suricata_alerts_1h="$(trend_last_value "${SURICATA_TREND_TSV}")"
mail_trend_age_min="$(file_age_minutes "${MAIL_TREND_TSV}")"
mail_connect_trend_age_min="$(file_age_minutes "${MAIL_CONNECT_TREND_TSV}")"
mail_reject_trend_age_min="$(file_age_minutes "${MAIL_REJECT_TREND_TSV}")"
mail_noncompliant_methods_age_min="$(file_age_minutes "${MAIL_NONCOMPLIANT_METHODS_TSV}")"
mail_connection_catalog_age_min="$(file_age_minutes "${MAIL_CONNECTION_CATALOG_TSV}")"
mail_connection_sources_age_min="$(file_age_minutes "${MAIL_CONNECTION_SOURCES_TSV}")"
suricata_trend_age_min="$(file_age_minutes "${SURICATA_TREND_TSV}")"

mailstack_latest="$(latest_file '/var/backups/openbsd-self-hosting/mailstack/*/mailstack-*.tar.gz')"
mysql_latest="$(latest_file '/var/backups/openbsd-self-hosting/mysql/*/*/*/*.log')"
backup_mailstack_age_min="-1"
backup_mysql_age_min="-1"
[ -n "${mailstack_latest}" ] && backup_mailstack_age_min="$(file_age_minutes "${mailstack_latest}")"
[ -n "${mysql_latest}" ] && backup_mysql_age_min="$(file_age_minutes "${mysql_latest}")"

dns_vultr_manifest_latest="$(latest_file '/var/backups/openbsd-self-hosting/mailstack/*/stage/var/backups/openbsd-self-hosting/dns/vultr-dump/*/_manifest.json')"
dns_vultr_snapshot_dir="none"
dns_vultr_age_min="-1"
dns_vultr_domain_count="0"
dns_vultr_record_count="0"
dns_vultr_generated_at="unknown"
dns_vultr_output_dir="none"
[ -n "${dns_vultr_manifest_latest}" ] && dns_vultr_age_min="$(file_age_minutes "${dns_vultr_manifest_latest}")"
if [ -n "${dns_vultr_manifest_latest}" ] && [ -r "${dns_vultr_manifest_latest}" ]; then
  dns_vultr_snapshot_dir="$(dirname "${dns_vultr_manifest_latest}")"
  dns_vultr_domain_count="$(json_num_path "${dns_vultr_manifest_latest}" '.domains | length' 0)"
  dns_vultr_record_count="$(json_num_path "${dns_vultr_manifest_latest}" '[.domains[].record_count] | add' 0)"
  dns_vultr_generated_at="$(json_string_path "${dns_vultr_manifest_latest}" '.generated_at' 'unknown')"
  dns_vultr_output_dir="$(json_string_path "${dns_vultr_manifest_latest}" '.output_dir' 'none')"
fi

wg_iface_present=0
wg_peer_count=0
wg_active_peer_count=0
if ifconfig "${WG_IF}" >/dev/null 2>&1; then
  wg_iface_present=1
  if command -v wg >/dev/null 2>&1; then
    wg_peer_count="$(wg show "${WG_IF}" 2>/dev/null | awk '/^peer:/ {c++} END {print c+0}')"
    wg_active_peer_count="$(wg show "${WG_IF}" 2>/dev/null | awk '/latest handshake:/ && $0 !~ /never/ {c++} END {print c+0}')"
  fi
fi

nginx_conf_ok=0
command -v nginx >/dev/null 2>&1 && nginx -t >/dev/null 2>&1 && nginx_conf_ok=1 || true
nginx_https_wg_listener="$(netstat -an -f inet -p tcp 2>/dev/null | awk 'toupper($0) ~ /LISTEN/ && $4 ~ /^10\.44\.0\.1\.443$/ {f=1} END {print f+0}')"
nginx_https_loop_listener="$(netstat -an -f inet -p tcp 2>/dev/null | awk 'toupper($0) ~ /LISTEN/ && $4 ~ /^127\.0\.0\.1\.443$/ {f=1} END {print f+0}')"

kv_set timestamp_epoch "${TS_EPOCH}"
kv_set timestamp_iso "${TS_ISO}"
kv_set host "${hostname_detected}"
kv_set uptime_line "${uptime_line}"
kv_set load_1 "${load_1:-0}"
kv_set load_5 "${load_5:-0}"
kv_set load_15 "${load_15:-0}"
kv_set cpu_user_pct "${cpu_user_pct:-0}"
kv_set cpu_sys_pct "${cpu_sys_pct:-0}"
kv_set cpu_idle_pct "${cpu_idle_pct:-0}"
kv_set mem_avm "${mem_avm:-0}"
kv_set mem_free "${mem_free:-0}"
kv_set root_use_pct "${root_use_pct:-0}"
kv_set var_use_pct "${var_use_pct:-0}"
kv_set home_use_pct "${home_use_pct:-0}"
kv_set root_inode_pct "${root_inode_pct:-0}"
kv_set var_inode_pct "${var_inode_pct:-0}"

kv_set svc_total "${svc_total}"
kv_set svc_ok "${svc_ok}"
kv_set svc_fail "${svc_fail}"
kv_set svc_fail_list "${svc_fail_list:-none}"
kv_set svc_non_daemon_count "${svc_non_daemon_count}"
kv_set svc_non_daemon_list "${svc_non_daemon_list:-none}"

kv_set pf_enabled "${pf_enabled}"
kv_set pf_states "${pf_states:-0}"
kv_set pf_tables "${pf_tables:-0}"
kv_set pf_packets_in_pass "${pf_packets_in_pass:-0}"
kv_set pf_packets_in_block "${pf_packets_in_block:-0}"
kv_set pf_packets_out_pass "${pf_packets_out_pass:-0}"
kv_set pf_packets_out_block "${pf_packets_out_block:-0}"
kv_set pf_synproxy "${pf_synproxy:-0}"

kv_set table_sshguard "${table_sshguard}"
kv_set table_smtp_abuse "${table_smtp_abuse}"
kv_set table_suricata_watch "${table_suricata_watch}"
kv_set table_suricata_block "${table_suricata_block}"
kv_set table_suricata_allow "${table_suricata_allow}"

kv_set tcp_listen_count "${tcp_listen_count:-0}"
kv_set udp_listener_count "${udp_listener_count:-0}"
kv_set public_tcp_count "${public_tcp_count:-0}"
kv_set public_udp_count "${public_udp_count:-0}"
kv_set public_tcp_list "${public_tcp_list:-none}"
kv_set public_udp_list "${public_udp_list:-none}"

kv_set mail_accepted "${mail_accepted:-0}"
kv_set mail_rejected "${mail_rejected:-0}"
kv_set mail_bounced "${mail_bounced:-0}"
kv_set mail_deferred "${mail_deferred:-0}"
kv_set mail_queue "${mail_queue:-0}"
kv_set rspamd_reject "${rspamd_reject:-0}"
kv_set rspamd_add_header "${rspamd_add_header:-0}"
kv_set rspamd_greylist "${rspamd_greylist:-0}"
kv_set rspamd_soft_reject "${rspamd_soft_reject:-0}"
kv_set vt_checks "${vt_checks:-0}"
kv_set vt_errors "${vt_errors:-0}"
kv_set mail_accepted_24h "${mail_accepted_24h:-0}"
kv_set mail_accepted_1h "${mail_accepted_1h:-0}"
kv_set mail_connect_24h "${mail_connect_24h:-0}"
kv_set mail_connect_1h "${mail_connect_1h:-0}"
kv_set mail_rejected_24h "${mail_rejected_24h:-0}"
kv_set mail_rejected_1h "${mail_rejected_1h:-0}"
kv_set mail_noncompliant_attempts_24h "${mail_noncompliant_attempts_24h:-0}"
kv_set mail_noncompliant_top_methods "${mail_noncompliant_top_methods:-none}"
kv_set mail_connection_catalog_top "${mail_connection_catalog_top:-none}"
kv_set mail_connection_source_top "${mail_connection_source_top:-none}"
kv_set mail_connection_events_total "${mail_connection_events_total:-0}"
kv_set mail_connection_rejected_total "${mail_connection_rejected_total:-0}"
kv_set mail_connection_noncompliant_total "${mail_connection_noncompliant_total:-0}"
kv_set mail_connection_lines_scanned "${mail_connection_lines_scanned:-0}"
kv_set mail_log_files_scanned "${mail_log_files_scanned:-0}"

kv_set suricata_alerts "${suricata_alerts:-0}"
kv_set suricata_blocked_totals "${suricata_blocked_totals:-0}"
kv_set suricata_drops_24h "${suricata_drops_24h:-0}"
kv_set suricata_alerts_24h "${suricata_alerts_24h:-0}"
kv_set suricata_alerts_1h "${suricata_alerts_1h:-0}"
kv_set suricata_top_blocked_sig "${suricata_top_blocked_sig:-none}"
kv_set suricata_top_source_ip "${suricata_top_source_ip:-none}"
kv_set suricata_top_source_hits "${suricata_top_source_hits:-0}"
kv_set suricata_last_blocked_ts "${suricata_last_blocked_ts:-none}"
kv_set suricata_status "${suricata_status:-unknown}"
kv_set suricata_version "${suricata_version:-unknown}"
kv_set suricata_log_dir "${suricata_log_dir:-/var/log/suricata}"
kv_set suricata_event_total "${suricata_event_total:-0}"
kv_set suricata_event_types_top "${suricata_event_types_top:-none}"
kv_set suricata_protocol_top "${suricata_protocol_top:-none}"
kv_set suricata_action_top "${suricata_action_top:-none}"
kv_set suricata_keywords_top "${suricata_keywords_top:-none}"
kv_set suricata_top_signatures_text "${suricata_top_signatures_text:-none}"
kv_set suricata_top_sources_text "${suricata_top_sources_text:-none}"
kv_set suricata_blocked_sample_count "${suricata_blocked_sample_count:-0}"
kv_set suricata_alert_sample_count "${suricata_alert_sample_count:-0}"
kv_set suricata_recent_blocked "${suricata_recent_blocked:-none}"
kv_set suricata_recent_alerts "${suricata_recent_alerts:-none}"
kv_set suricata_eve2pf_mode "${suricata_eve2pf_mode:-unknown}"
kv_set suricata_eve2pf_table "${suricata_eve2pf_table:-unknown}"
kv_set suricata_eve2pf_candidates "${suricata_eve2pf_candidates:-0}"
kv_set suricata_eve2pf_window_s "${suricata_eve2pf_window_s:-0}"
kv_set suricata_eve2pf_last_ts "${suricata_eve2pf_last_ts:-none}"
kv_set suricata_eve2pf_log_age_min "${suricata_eve2pf_log_age_min}"

kv_set verify_status "${verify_status:-unknown}"
kv_set verify_fail "${verify_fail:-0}"
kv_set verify_warn "${verify_warn:-0}"
kv_set verify_public_ports "${verify_public_ports:-none}"

kv_set cron_fail_count "${cron_fail_count}"
kv_set cron_warn_count "${cron_warn_count}"
kv_set cron_fail_jobs "${cron_fail_jobs:-none}"
kv_set cron_warn_jobs "${cron_warn_jobs:-none}"
kv_set cron_fail_context "${cron_fail_context:-none}"
kv_set cron_warn_context "${cron_warn_context:-none}"
kv_set sbom_daily_status "${sbom_daily_status:-UNKNOWN}"
kv_set sbom_weekly_status "${sbom_weekly_status:-UNKNOWN}"
kv_set sbom_daily_exit_code "${sbom_daily_exit_code:-0}"
kv_set sbom_weekly_exit_code "${sbom_weekly_exit_code:-0}"
kv_set sbom_daily_age_min "${sbom_daily_age_min}"
kv_set sbom_weekly_age_min "${sbom_weekly_age_min}"
kv_set cron_mailto_ops "${cron_mailto_ops}"
kv_set cron_weekly_maintenance_4am "${cron_weekly_maintenance_4am}"
kv_set cron_weekly_maintenance_apply_wrapped "${cron_weekly_maintenance_apply_wrapped}"
kv_set cron_weekly_maintenance_post_reboot_wrapped "${cron_weekly_maintenance_post_reboot_wrapped}"
kv_set cron_daily_patch_scan "${cron_daily_patch_scan}"
kv_set cron_regression_gate "${cron_regression_gate}"
kv_set suricata_mode_block_cron "${suricata_mode_block_cron}"
kv_set cron_html_report_count "${cron_html_report_count}"
kv_set cron_reports_24h "${cron_reports_24h}"
kv_set cron_report_latest_age_min "${cron_report_latest_age_min}"
kv_set weekly_maintenance_structured_report "${weekly_maintenance_structured_report}"
kv_set weekly_maintenance_apply_status "${weekly_maintenance_apply_status:-UNKNOWN}"
kv_set weekly_maintenance_apply_age_min "${weekly_maintenance_apply_age_min}"
kv_set weekly_maintenance_post_status "${weekly_maintenance_post_status:-UNKNOWN}"
kv_set weekly_maintenance_post_age_min "${weekly_maintenance_post_age_min}"
kv_set weekly_maintenance_log_age_min "${weekly_maintenance_log_age_min}"
kv_set maint_last_log_age_min "${maint_last_log_age_min}"
kv_set regression_gate_log_age_min "${regression_gate_log_age_min}"
kv_set weekly_maintenance_pending "${weekly_maintenance_pending}"
kv_set maint_last_regression_pass "${maint_last_regression_pass}"
kv_set doas_policy_weekly_status "${doas_policy_weekly_status:-UNKNOWN}"
kv_set doas_policy_weekly_age_min "${doas_policy_weekly_age_min}"
kv_set ssh_hardening_weekly_status "${ssh_hardening_weekly_status:-UNKNOWN}"
kv_set ssh_hardening_weekly_age_min "${ssh_hardening_weekly_age_min}"
kv_set ssh_hardening_state "${ssh_hardening_state:-unknown}"
kv_set ssh_hardening_mismatch_count "${ssh_hardening_mismatch_count:-0}"
kv_set ssh_hardening_mismatches "${ssh_hardening_mismatches:-none}"
kv_set ssh_hardening_syntax_ok "${ssh_hardening_syntax_ok:-0}"
kv_set ssh_hardening_service_ok "${ssh_hardening_service_ok:-0}"
kv_set ssh_hardening_listener_ok "${ssh_hardening_listener_ok:-0}"
kv_set doas_policy_state "${doas_policy_state:-unknown}"
kv_set doas_live_valid "${doas_live_valid:-0}"
kv_set doas_policy_drift "${doas_policy_drift:-0}"
kv_set doas_policy_missing_rules "${doas_policy_missing_rules:-none}"
kv_set doas_policy_extra_rules "${doas_policy_extra_rules:-none}"
kv_set doas_automation_overlay_present "${doas_automation_overlay_present:-0}"
kv_set maint_plan_status "${maint_plan_status:-UNKNOWN}"
kv_set maint_plan_exit_code "${maint_plan_exit_code:-0}"
kv_set maint_plan_age_min "${maint_plan_age_min}"
kv_set maint_plan_log_file "${maint_plan_log_file:-none}"
kv_set syspatch_pending_count "${syspatch_pending_count:-0}"
kv_set syspatch_pending_list "${syspatch_pending_list:-none}"
kv_set syspatch_installed_count "${syspatch_installed_count:-0}"
kv_set syspatch_up_to_date "${syspatch_up_to_date:-0}"
kv_set syspatch_data_source "${syspatch_data_source:-unknown}"
kv_set syspatch_check_status "${syspatch_check_status:-unknown}"
kv_set syspatch_check_rc "${syspatch_check_rc:-0}"
kv_set pkg_upgrade_runs_total "${pkg_upgrade_runs_total:-0}"
kv_set pkg_upgrade_last_run_ts "${pkg_upgrade_last_run_ts:-none}"
kv_set pkg_upgrade_last_run_age_min "${pkg_upgrade_last_run_age_min}"
kv_set pkg_upgrade_last_apply_ts "${pkg_upgrade_last_apply_ts:-none}"
kv_set pkg_upgrade_last_apply_age_min "${pkg_upgrade_last_apply_age_min}"
kv_set pkg_upgrade_last_post_verify_ts "${pkg_upgrade_last_post_verify_ts:-none}"
kv_set pkg_upgrade_last_post_verify_status "${pkg_upgrade_last_post_verify_status:-none}"
kv_set pkg_add_u_recent "${pkg_add_u_recent:-0}"
kv_set pkg_snapshot_age_min "${pkg_snapshot_age_min}"
kv_set pkg_snapshot_count "${pkg_snapshot_count:-0}"
kv_set sbom_report_age_min "${sbom_report_age_min}"
kv_set sbom_scanner "${sbom_scanner:-unknown}"
kv_set sbom_package_count "${sbom_package_count:-0}"
kv_set sbom_severity_critical "${sbom_severity_critical:-0}"
kv_set sbom_severity_high "${sbom_severity_high:-0}"
kv_set sbom_severity_medium "${sbom_severity_medium:-0}"
kv_set sbom_severity_low "${sbom_severity_low:-0}"
kv_set sbom_severity_unknown "${sbom_severity_unknown:-0}"
kv_set sbom_vuln_total "${sbom_vuln_total:-0}"
kv_set sbom_exceptions_total "${sbom_exceptions_total:-0}"
kv_set sbom_exceptions_expired "${sbom_exceptions_expired:-0}"
kv_set sbom_exceptions_invalid "${sbom_exceptions_invalid:-0}"
kv_set sbom_capability_mode "${sbom_capability_mode:-unknown}"
kv_set cve_mapping_supported "${cve_mapping_supported:-0}"
kv_set cve_associated_findings "${cve_associated_findings:-0}"
kv_set cve_association_status "${cve_association_status:-unknown}"
kv_set cve_summary_note "${cve_summary_note:-none}"
kv_set report_trust_state "${report_trust_state:-unknown}"
kv_set report_trust_false_green_count "${report_trust_false_green_count:-0}"
kv_set report_trust_advisory_count "${report_trust_advisory_count:-0}"
kv_set report_trust_reasons "${report_trust_reasons:-none}"
kv_set lifecycle_gap_state "${lifecycle_gap_state:-unknown}"
kv_set lifecycle_gap_reasons "${lifecycle_gap_reasons:-none}"

kv_set pfstats_age_min "${pfstats_age_min}"
kv_set mailstats_age_min "${mailstats_age_min}"
kv_set suricata_age_min "${suricata_age_min}"
kv_set verify_age_min "${verify_age_min}"
kv_set sshguard_age_min "${sshguard_age_min}"
kv_set brevo_age_min "${brevo_age_min}"
kv_set mail_trend_age_min "${mail_trend_age_min}"
kv_set mail_connect_trend_age_min "${mail_connect_trend_age_min}"
kv_set mail_reject_trend_age_min "${mail_reject_trend_age_min}"
kv_set mail_noncompliant_methods_age_min "${mail_noncompliant_methods_age_min}"
kv_set mail_connection_catalog_age_min "${mail_connection_catalog_age_min}"
kv_set mail_connection_sources_age_min "${mail_connection_sources_age_min}"
kv_set suricata_trend_age_min "${suricata_trend_age_min}"

kv_set backup_mailstack_age_min "${backup_mailstack_age_min}"
kv_set backup_mysql_age_min "${backup_mysql_age_min}"
kv_set backup_mailstack_latest_path "${mailstack_latest:-none}"
kv_set backup_mysql_latest_path "${mysql_latest:-none}"
kv_set dns_vultr_manifest_path "${dns_vultr_manifest_latest:-none}"
kv_set dns_vultr_snapshot_dir "${dns_vultr_snapshot_dir}"
kv_set dns_vultr_age_min "${dns_vultr_age_min}"
kv_set dns_vultr_domain_count "${dns_vultr_domain_count}"
kv_set dns_vultr_record_count "${dns_vultr_record_count}"
kv_set dns_vultr_generated_at "${dns_vultr_generated_at}"
kv_set dns_vultr_output_dir "${dns_vultr_output_dir}"
kv_set wg_iface_present "${wg_iface_present}"
kv_set wg_peer_count "${wg_peer_count}"
kv_set wg_active_peer_count "${wg_active_peer_count}"

kv_set nginx_conf_ok "${nginx_conf_ok}"
kv_set nginx_https_wg_listener "${nginx_https_wg_listener}"
kv_set nginx_https_loop_listener "${nginx_https_loop_listener}"

SNAP_KV="${SNAP_DIR}/${STAMP}.kv"
SNAP_JSON="${SNAP_DIR}/${STAMP}.json"

atomic_install 0644 "${KV_TMP}" "${SNAP_KV}"
kv_to_json "${KV_TMP}" > "${JSON_TMP}"
atomic_install 0644 "${JSON_TMP}" "${SNAP_JSON}"
atomic_install 0644 "${KV_TMP}" "${DATA_ROOT}/latest.kv"
atomic_install 0644 "${JSON_TMP}" "${DATA_ROOT}/latest.json"

for ext in kv json; do
  old_list="$(ls -1t "${SNAP_DIR}"/*.${ext} 2>/dev/null | awk "NR>${KEEP_COUNT}" || true)"
  if [ -n "${old_list}" ]; then
    printf '%s\n' "${old_list}" | while IFS= read -r f; do
      [ -n "${f}" ] && rm -f "${f}"
    done
  fi
  find "${SNAP_DIR}" -type f -name "*.${ext}" -mtime +"${KEEP_DAYS}" -exec rm -f {} + 2>/dev/null || true
done

printf 'snapshot=%s\n' "${SNAP_KV}"
