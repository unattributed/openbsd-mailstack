#!/bin/ksh
REPO_ROOT_DEFAULT="$(cd "$(dirname "$0")/../.." && pwd -P)"
# =============================================================================
# sbom/bin/sbom-scan-nvd-mapped.ksh
# =============================================================================
# Summary:
#   scan mapped mail-stack components against NVD by exact CPE and optionally
#   enrich matched CVE IDs from MITRE CVE Services.
#
# Notes:
#   - The inventory may contain application entries without a CPE; those stay
#     visible in coverage reporting but are not queried against NVD.
#   - Source-installed applications may be auto-detected by inventory probes or
#     declared explicitly in manual-components.tsv.
#
# Usage:
#   sbom-scan-nvd-mapped.ksh [--repo <path>] [--inventory <path>] \
#     [--exceptions <path>] [--json-out <path>] [--txt-out <path>] \
#     [--cpe-map <path>] [--manual-components <path>] [--no-mitre]
# =============================================================================

set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

REPO_ROOT="${REPO_ROOT_DEFAULT}"
HOST_NAME="$(hostname)"
INVENTORY_FILE=""
EXCEPTIONS_FILE=""
JSON_OUT=""
TXT_OUT=""
CPE_MAP_FILE=""
MANUAL_COMPONENTS_FILE=""
TAB="$(printf '\t')"

NVD_API_URL="${NVD_API_URL:-https://services.nvd.nist.gov/rest/json/cves/2.0}"
MITRE_API_BASE="${MITRE_API_BASE:-https://cveawg.mitre.org/api/cve}"
NVD_API_KEY="${NVD_API_KEY:-}"
MITRE_ENRICH="${SBOM_CVE_ENRICH_MITRE:-1}"
NVD_MIN_INTERVAL_SECONDS="${NVD_MIN_INTERVAL_SECONDS:-7}"
NVD_MIN_INTERVAL_KEYED_SECONDS="${NVD_MIN_INTERVAL_KEYED_SECONDS:-1}"
NVD_RESULTS_PER_PAGE="${NVD_RESULTS_PER_PAGE:-2000}"
CURL_CONNECT_TIMEOUT_SECONDS="${SBOM_CURL_CONNECT_TIMEOUT_SECONDS:-10}"
CURL_MAX_TIME_SECONDS="${SBOM_CURL_MAX_TIME_SECONDS:-30}"
SCANNER_NAME="nvd-cpe-mapped"

usage() {
  cat <<'USAGE' >&2
usage: sbom-scan-nvd-mapped.ksh [--repo <path>] [--inventory <path>] [--exceptions <path>] [--json-out <path>] [--txt-out <path>] [--cpe-map <path>] [--manual-components <path>] [--no-mitre]
USAGE
  exit 2
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

emit_exception_json() {
  jq -nc \
    --arg id "$1" \
    --arg package "$2" \
    --arg reason "$3" \
    --arg owner "$4" \
    --arg expires_on "$5" \
    '{
      id: $id,
      package: $package,
      reason: $reason,
      owner: $owner,
      expires_on: $expires_on
    }'
}

json_array_from_jsonl() {
  _src="$1"
  _dst="$2"
  if [ -s "${_src}" ]; then
    jq -s '.' "${_src}" > "${_dst}"
  else
    printf '[]\n' > "${_dst}"
  fi
}

replace_version_token() {
  awk -v tmpl="$1" -v version="$2" 'BEGIN { gsub(/%VERSION%/, version, tmpl); printf "%s", tmpl }'
}

register_component() {
  _origin="$1"
  _component="$2"
  _version="$3"
  _cpe="$4"
  _installed_package="$5"
  _note="$6"
  _key="${_component}|${_version}|${_cpe}|${_installed_package}"

  if grep -qxF "${_key}" "${COMPONENT_KEYS_FILE}" 2>/dev/null; then
    return 0
  fi

  printf '%s\n' "${_key}" >> "${COMPONENT_KEYS_FILE}"
  jq -nc \
    --arg origin "${_origin}" \
    --arg component "${_component}" \
    --arg installed_version "${_version}" \
    --arg cpe "${_cpe}" \
    --arg installed_package "${_installed_package}" \
    --arg note "${_note}" \
    '{
      origin: $origin,
      component: $component,
      installed_version: $installed_version,
      cpe: $cpe,
      installed_package: $installed_package,
      note: $note
    }' >> "${COMPONENTS_JSONL}"
}

match_exception_state() {
  _component="$1"
  _installed_package="$2"
  _current_match="$(awk -F'\t' -v a="${_component}" -v b="${_installed_package}" '
    NF >= 5 && ($2 == a || $2 == b) { print $2; exit }
  ' "${CURRENT_EXCEPTION_ROWS}" 2>/dev/null || true)"
  if [ -n "${_current_match}" ]; then
    printf 'current:%s\n' "${_current_match}"
    return 0
  fi

  _expired_match="$(awk -F'\t' -v a="${_component}" -v b="${_installed_package}" '
    NF >= 5 && ($2 == a || $2 == b) { print $2; exit }
  ' "${EXPIRED_EXCEPTION_ROWS}" 2>/dev/null || true)"
  if [ -n "${_expired_match}" ]; then
    printf 'expired:%s\n' "${_expired_match}"
    return 0
  fi

  printf 'none:\n'
}

NVD_LAST_REQUEST_EPOCH=0
nvd_throttle() {
  _min="${NVD_MIN_INTERVAL_SECONDS}"
  [ -n "${NVD_API_KEY}" ] && _min="${NVD_MIN_INTERVAL_KEYED_SECONDS}"
  [ "${_min}" -gt 0 ] 2>/dev/null || return 0

  _now="$(date +%s)"
  if [ "${NVD_LAST_REQUEST_EPOCH}" -gt 0 ]; then
    (( _elapsed = _now - NVD_LAST_REQUEST_EPOCH ))
    if [ "${_elapsed}" -lt "${_min}" ]; then
      sleep $((_min - _elapsed))
    fi
  fi
  NVD_LAST_REQUEST_EPOCH="$(date +%s)"
}

fetch_nvd_page() {
  _cpe="$1"
  _start="$2"
  _out="$3"

  nvd_throttle
  if [ -n "${NVD_API_KEY}" ]; then
    curl -fsS -G "${NVD_API_URL}" \
      --connect-timeout "${CURL_CONNECT_TIMEOUT_SECONDS}" \
      --max-time "${CURL_MAX_TIME_SECONDS}" \
      -H "apiKey: ${NVD_API_KEY}" \
      --data-urlencode "cpeName=${_cpe}" \
      --data-urlencode "startIndex=${_start}" \
      --data-urlencode "resultsPerPage=${NVD_RESULTS_PER_PAGE}" \
      > "${_out}"
  else
    curl -fsS -G "${NVD_API_URL}" \
      --connect-timeout "${CURL_CONNECT_TIMEOUT_SECONDS}" \
      --max-time "${CURL_MAX_TIME_SECONDS}" \
      --data-urlencode "cpeName=${_cpe}" \
      --data-urlencode "startIndex=${_start}" \
      --data-urlencode "resultsPerPage=${NVD_RESULTS_PER_PAGE}" \
      > "${_out}"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      [ $# -ge 2 ] || usage
      REPO_ROOT="$2"
      shift 2
      ;;
    --inventory)
      [ $# -ge 2 ] || usage
      INVENTORY_FILE="$2"
      shift 2
      ;;
    --exceptions)
      [ $# -ge 2 ] || usage
      EXCEPTIONS_FILE="$2"
      shift 2
      ;;
    --json-out)
      [ $# -ge 2 ] || usage
      JSON_OUT="$2"
      shift 2
      ;;
    --txt-out)
      [ $# -ge 2 ] || usage
      TXT_OUT="$2"
      shift 2
      ;;
    --cpe-map)
      [ $# -ge 2 ] || usage
      CPE_MAP_FILE="$2"
      shift 2
      ;;
    --manual-components)
      [ $# -ge 2 ] || usage
      MANUAL_COMPONENTS_FILE="$2"
      shift 2
      ;;
    --no-mitre)
      MITRE_ENRICH=0
      shift 1
      ;;
    --help|-h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

need_cmd curl
need_cmd jq
need_cmd sed
need_cmd awk
need_cmd mktemp
need_cmd install
need_cmd sort

[ -n "${INVENTORY_FILE}" ] || INVENTORY_FILE="${REPO_ROOT}/.work/advanced/sbom/host-inventory-${HOST_NAME}.json"
[ -n "${EXCEPTIONS_FILE}" ] || EXCEPTIONS_FILE="${REPO_ROOT}/services/sbom/exceptions/exceptions.tsv"
[ -n "${JSON_OUT}" ] || JSON_OUT="${REPO_ROOT}/.work/advanced/sbom/scan-report.json"
[ -n "${TXT_OUT}" ] || TXT_OUT="${REPO_ROOT}/.work/advanced/sbom/scan-report.txt"
[ -n "${CPE_MAP_FILE}" ] || CPE_MAP_FILE="${REPO_ROOT}/services/sbom/components/cpe-map.tsv"
[ -n "${MANUAL_COMPONENTS_FILE}" ] || MANUAL_COMPONENTS_FILE="${REPO_ROOT}/services/sbom/components/manual-components.tsv"

[ -f "${INVENTORY_FILE}" ] || {
  echo "error: inventory file not found: ${INVENTORY_FILE}" >&2
  exit 1
}
[ -f "${EXCEPTIONS_FILE}" ] || {
  echo "error: exceptions file not found: ${EXCEPTIONS_FILE}" >&2
  exit 1
}
[ -f "${CPE_MAP_FILE}" ] || {
  echo "error: cpe map file not found: ${CPE_MAP_FILE}" >&2
  exit 1
}

TMP_DIR="$(mktemp -d /tmp/sbom-nvd-mapped.XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT INT TERM

PACKAGES_FILE="${TMP_DIR}/packages.txt"
COMPONENT_KEYS_FILE="${TMP_DIR}/component-keys.txt"
COMPONENTS_JSONL="${TMP_DIR}/components.jsonl"
COMPONENTS_JSON="${TMP_DIR}/components.json"
FINDINGS_JSONL="${TMP_DIR}/findings.jsonl"
FINDINGS_TMP_JSONL="${TMP_DIR}/findings-tmp.jsonl"
FINDINGS_JSON="${TMP_DIR}/findings.json"
QUERY_ERRORS_JSONL="${TMP_DIR}/query-errors.jsonl"
QUERY_ERRORS_JSON="${TMP_DIR}/query-errors.json"
MITRE_ERRORS_JSONL="${TMP_DIR}/mitre-errors.jsonl"
MITRE_ERRORS_JSON="${TMP_DIR}/mitre-errors.json"
ACTIVE_EXCEPTIONS_JSONL="${TMP_DIR}/exceptions-active.jsonl"
ACTIVE_EXCEPTIONS_JSON="${TMP_DIR}/exceptions-active.json"
EXPIRED_EXCEPTIONS_JSONL="${TMP_DIR}/exceptions-expired.jsonl"
EXPIRED_EXCEPTIONS_JSON="${TMP_DIR}/exceptions-expired.json"
INVENTORY_APPLICATIONS_JSON="${TMP_DIR}/inventory-applications.json"
INVENTORY_ONLY_APPLICATIONS_JSON="${TMP_DIR}/inventory-only-applications.json"
UNMAPPED_APPLICATIONS_JSON="${TMP_DIR}/unmapped-applications.json"
CURRENT_EXCEPTION_ROWS="${TMP_DIR}/exceptions-current.tsv"
EXPIRED_EXCEPTION_ROWS="${TMP_DIR}/exceptions-expired.tsv"
BODY_JSON="${TMP_DIR}/api-body.json"

: > "${COMPONENT_KEYS_FILE}"
: > "${COMPONENTS_JSONL}"
: > "${FINDINGS_JSONL}"
: > "${QUERY_ERRORS_JSONL}"
: > "${MITRE_ERRORS_JSONL}"
: > "${ACTIVE_EXCEPTIONS_JSONL}"
: > "${EXPIRED_EXCEPTIONS_JSONL}"
: > "${CURRENT_EXCEPTION_ROWS}"
: > "${EXPIRED_EXCEPTION_ROWS}"

if jq -e '.applications? | type == "array"' "${INVENTORY_FILE}" >/dev/null 2>&1; then
  jq '.applications // []' "${INVENTORY_FILE}" > "${INVENTORY_APPLICATIONS_JSON}"
  jq '[.applications[]? | select(((.cpe // "") == "") and ((.inventory_only // false) == true))]' "${INVENTORY_FILE}" > "${INVENTORY_ONLY_APPLICATIONS_JSON}"
  jq '[.applications[]? | select(((.cpe // "") == "") and ((.inventory_only // false) != true))]' "${INVENTORY_FILE}" > "${UNMAPPED_APPLICATIONS_JSON}"
else
  printf '[]\n' > "${INVENTORY_APPLICATIONS_JSON}"
  printf '[]\n' > "${INVENTORY_ONLY_APPLICATIONS_JSON}"
  printf '[]\n' > "${UNMAPPED_APPLICATIONS_JSON}"
fi

pkg_count="$(jq -r '.package_count // 0' "${INVENTORY_FILE}")"
package_inventory_count="$(jq -r '(.package_inventory // []) | length' "${INVENTORY_FILE}")"
openbsd_release="$(jq -r '.openbsd_release // ""' "${INVENTORY_FILE}")"
errata_url="$(jq -r '.errata_url // ""' "${INVENTORY_FILE}")"
enabled_service_count="$(jq -r '(.enabled_services // []) | length' "${INVENTORY_FILE}")"
syspatches_installed_count="$(jq -r '(.syspatches_installed // []) | length' "${INVENTORY_FILE}")"
jq -r '.packages[]? // empty' "${INVENTORY_FILE}" | sort -u > "${PACKAGES_FILE}"

today="$(date +%Y-%m-%d)"
active_total=0
expired_total=0
invalid_total=0

while IFS="${TAB}" read -r id pkg reason owner expires; do
  case "${id}" in
    ''|\#*) continue ;;
  esac

  if [ -z "${pkg}" ] || [ -z "${reason}" ] || [ -z "${owner}" ] || [ -z "${expires}" ]; then
    (( invalid_total = invalid_total + 1 ))
    continue
  fi

  (( active_total = active_total + 1 ))
  emit_exception_json "${id}" "${pkg}" "${reason}" "${owner}" "${expires}" >> "${ACTIVE_EXCEPTIONS_JSONL}"

  if [ "${expires}" \< "${today}" ]; then
    (( expired_total = expired_total + 1 ))
    printf '%s\t%s\t%s\t%s\t%s\n' "${id}" "${pkg}" "${reason}" "${owner}" "${expires}" >> "${EXPIRED_EXCEPTION_ROWS}"
    emit_exception_json "${id}" "${pkg}" "${reason}" "${owner}" "${expires}" >> "${EXPIRED_EXCEPTIONS_JSONL}"
  else
    printf '%s\t%s\t%s\t%s\t%s\n' "${id}" "${pkg}" "${reason}" "${owner}" "${expires}" >> "${CURRENT_EXCEPTION_ROWS}"
  fi
done < "${EXCEPTIONS_FILE}"

if jq -e '.applications? | type == "array"' "${INVENTORY_FILE}" >/dev/null 2>&1; then
  jq -c '.applications[]?' "${INVENTORY_FILE}" | while IFS= read -r app_json; do
    [ -n "${app_json}" ] || continue
    origin="$(printf '%s\n' "${app_json}" | jq -r '.origin // "inventory"')"
    component="$(printf '%s\n' "${app_json}" | jq -r '.component // ""')"
    version="$(printf '%s\n' "${app_json}" | jq -r '.installed_version // .version // ""')"
    cpe="$(printf '%s\n' "${app_json}" | jq -r '.cpe // ""')"
    installed_package="$(printf '%s\n' "${app_json}" | jq -r '.installed_package // .component // ""')"
    note="$(printf '%s\n' "${app_json}" | jq -r '.note // "inventory application entry"')"
    [ -n "${component}" ] || continue
    [ -n "${version}" ] || continue
    [ -n "${cpe}" ] || continue
    register_component "${origin}" "${component}" "${version}" "${cpe}" "${installed_package}" "${note}"
  done
fi

while IFS= read -r pkg; do
  [ -n "${pkg}" ] || continue
  while IFS="${TAB}" read -r match_regex component cpe_template note; do
    case "${match_regex}" in
      ''|\#*) continue ;;
    esac

    version="$(printf '%s\n' "${pkg}" | sed -En "s~${match_regex}~\\1~p" | head -n 1 || true)"
    if [ -n "${version}" ]; then
      cpe="$(replace_version_token "${cpe_template}" "${version}")"
      [ "${cpe}" = "inventory_only" ] && cpe=""
      if [ -n "${cpe}" ]; then
        register_component "inventory" "${component}" "${version}" "${cpe}" "${pkg}" "${note}"
      fi
      break
    fi
  done < "${CPE_MAP_FILE}"
done < "${PACKAGES_FILE}"

if [ -f "${MANUAL_COMPONENTS_FILE}" ]; then
  while IFS="${TAB}" read -r component version cpe note; do
    case "${component}" in
      ''|\#*) continue ;;
    esac
    [ -n "${version}" ] || continue
    [ "${cpe}" = "inventory_only" ] && cpe=""
    [ -n "${cpe}" ] || continue
    register_component "manual" "${component}" "${version}" "${cpe}" "${component}" "${note:-manual component manifest}"
  done < "${MANUAL_COMPONENTS_FILE}"
fi

json_array_from_jsonl "${ACTIVE_EXCEPTIONS_JSONL}" "${ACTIVE_EXCEPTIONS_JSON}"
json_array_from_jsonl "${EXPIRED_EXCEPTIONS_JSONL}" "${EXPIRED_EXCEPTIONS_JSON}"
json_array_from_jsonl "${COMPONENTS_JSONL}" "${COMPONENTS_JSON}"

if [ -s "${COMPONENTS_JSONL}" ]; then
  while IFS= read -r component_json; do
    [ -n "${component_json}" ] || continue

    component="$(printf '%s\n' "${component_json}" | jq -r '.component')"
    version="$(printf '%s\n' "${component_json}" | jq -r '.installed_version')"
    installed_package="$(printf '%s\n' "${component_json}" | jq -r '.installed_package')"
    cpe="$(printf '%s\n' "${component_json}" | jq -r '.cpe')"

    start_index=0
    total_results=-1

    while :; do
      if ! fetch_nvd_page "${cpe}" "${start_index}" "${BODY_JSON}"; then
        jq -nc \
          --arg component "${component}" \
          --arg installed_version "${version}" \
          --arg installed_package "${installed_package}" \
          --arg cpe "${cpe}" \
          --arg stage "nvd_query" \
          '{
            stage: $stage,
            component: $component,
            installed_version: $installed_version,
            installed_package: $installed_package,
            cpe: $cpe
          }' >> "${QUERY_ERRORS_JSONL}"
        break
      fi

      if ! jq -e '.vulnerabilities? | type == "array"' "${BODY_JSON}" >/dev/null 2>&1; then
        jq -nc \
          --arg component "${component}" \
          --arg installed_version "${version}" \
          --arg installed_package "${installed_package}" \
          --arg cpe "${cpe}" \
          --arg stage "nvd_parse" \
          '{
            stage: $stage,
            component: $component,
            installed_version: $installed_version,
            installed_package: $installed_package,
            cpe: $cpe
          }' >> "${QUERY_ERRORS_JSONL}"
        break
      fi

      if [ "${total_results}" -lt 0 ]; then
        total_results="$(jq -r '.totalResults // 0' "${BODY_JSON}")"
      fi

      jq -c \
        --arg component "${component}" \
        --arg installed_version "${version}" \
        --arg installed_package "${installed_package}" \
        --arg cpe "${cpe}" \
        '
        def metric:
          .metrics.cvssMetricV40[0]? //
          .metrics.cvssMetricV31[0]? //
          .metrics.cvssMetricV30[0]? //
          .metrics.cvssMetricV2[0]?;
        .vulnerabilities[]?.cve
        | {
            cve_id: .id,
            component: $component,
            installed_version: $installed_version,
            installed_package: $installed_package,
            cpe: $cpe,
            source: "nvd",
            published: (.published // ""),
            last_modified: (.lastModified // ""),
            severity: ((metric.cvssData.baseSeverity // "UNKNOWN") | ascii_downcase),
            score: (metric.cvssData.baseScore // 0),
            description: ((first(.descriptions[]? | select(.lang == "en") | .value) // "")),
            nvd_url: ("https://nvd.nist.gov/vuln/detail/" + .id),
            mitre_enriched: false,
            mitre_state: "",
            mitre_description: ""
          }
        ' "${BODY_JSON}" >> "${FINDINGS_JSONL}"

      (( start_index = start_index + NVD_RESULTS_PER_PAGE ))
      [ "${start_index}" -lt "${total_results}" ] || break
    done
  done < "${COMPONENTS_JSONL}"
fi

if [ "${MITRE_ENRICH}" = "1" ] && [ -s "${FINDINGS_JSONL}" ]; then
  : > "${FINDINGS_TMP_JSONL}"
  while IFS= read -r finding_json; do
    [ -n "${finding_json}" ] || continue
    cve_id="$(printf '%s\n' "${finding_json}" | jq -r '.cve_id')"

    if curl -fsS \
         --connect-timeout "${CURL_CONNECT_TIMEOUT_SECONDS}" \
         --max-time "${CURL_MAX_TIME_SECONDS}" \
         "${MITRE_API_BASE}/${cve_id}" > "${BODY_JSON}" && \
       jq -e '.cveMetadata.cveId == "'"${cve_id}"'"' "${BODY_JSON}" >/dev/null 2>&1; then
      mitre_state="$(jq -r '.cveMetadata.state // ""' "${BODY_JSON}")"
      mitre_description="$(jq -r '([.containers.cna.descriptions[]? | select(.lang == "en") | .value][0]) // ""' "${BODY_JSON}")"
      printf '%s\n' "${finding_json}" | jq -c \
        --arg mitre_state "${mitre_state}" \
        --arg mitre_description "${mitre_description}" \
        '.mitre_enriched = true
         | .mitre_state = $mitre_state
         | .mitre_description = (if $mitre_description != "" then $mitre_description else .description end)' \
        >> "${FINDINGS_TMP_JSONL}"
    else
      jq -nc \
        --arg cve_id "${cve_id}" \
        --arg stage "mitre_lookup" \
        '{
          stage: $stage,
          cve_id: $cve_id
        }' >> "${MITRE_ERRORS_JSONL}"
      printf '%s\n' "${finding_json}" >> "${FINDINGS_TMP_JSONL}"
    fi
  done < "${FINDINGS_JSONL}"
  mv "${FINDINGS_TMP_JSONL}" "${FINDINGS_JSONL}"
fi

if [ -s "${FINDINGS_JSONL}" ]; then
  : > "${FINDINGS_TMP_JSONL}"
  while IFS= read -r finding_json; do
    [ -n "${finding_json}" ] || continue
    component="$(printf '%s\n' "${finding_json}" | jq -r '.component')"
    installed_package="$(printf '%s\n' "${finding_json}" | jq -r '.installed_package')"
    match_state="$(match_exception_state "${component}" "${installed_package}")"
    match_kind="${match_state%%:*}"
    match_name="${match_state#*:}"
    case "${match_kind}" in
      current)
        excepted=true
        expired=false
        ;;
      expired)
        excepted=false
        expired=true
        ;;
      *)
        excepted=false
        expired=false
        ;;
    esac
    printf '%s\n' "${finding_json}" | jq -c \
      --arg match_name "${match_name}" \
      --argjson excepted "${excepted}" \
      --argjson exception_expired "${expired}" \
      '.excepted = $excepted
       | .exception_expired = $exception_expired
       | .exception_match = $match_name' \
      >> "${FINDINGS_TMP_JSONL}"
  done < "${FINDINGS_JSONL}"
  mv "${FINDINGS_TMP_JSONL}" "${FINDINGS_JSONL}"
fi

json_array_from_jsonl "${FINDINGS_JSONL}" "${FINDINGS_JSON}"
json_array_from_jsonl "${QUERY_ERRORS_JSONL}" "${QUERY_ERRORS_JSON}"
json_array_from_jsonl "${MITRE_ERRORS_JSONL}" "${MITRE_ERRORS_JSON}"

severity_counts_tsv="$(jq -r '
  def bucket($s):
    if $s == "critical" then "critical"
    elif $s == "high" then "high"
    elif $s == "medium" then "medium"
    elif $s == "low" then "low"
    else "unknown" end;
  reduce .[] as $item ({critical:0, high:0, medium:0, low:0, unknown:0};
    .[bucket($item.severity)] += 1
  ) | [.critical, .high, .medium, .low, .unknown] | @tsv
' "${FINDINGS_JSON}")"

IFS='	' read -r severity_critical severity_high severity_medium severity_low severity_unknown <<EOF
${severity_counts_tsv}
EOF

component_count="$(jq -r 'length' "${COMPONENTS_JSON}")"
findings_total="$(jq -r 'length' "${FINDINGS_JSON}")"
manual_component_count="$(jq -r '[.[] | select(.origin == "manual" or .origin == "manual_manifest")] | length' "${COMPONENTS_JSON}")"
inventory_application_count="$(jq -r 'length' "${INVENTORY_APPLICATIONS_JSON}")"
inventory_only_application_count="$(jq -r 'length' "${INVENTORY_ONLY_APPLICATIONS_JSON}")"
unmapped_application_count="$(jq -r 'length' "${UNMAPPED_APPLICATIONS_JSON}")"
query_errors_total="$(jq -r 'length' "${QUERY_ERRORS_JSON}")"
mitre_errors_total="$(jq -r 'length' "${MITRE_ERRORS_JSON}")"
generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

install -d -m 0755 "$(dirname "${JSON_OUT}")" "$(dirname "${TXT_OUT}")"

jq -n \
  --arg generated_at "${generated_at}" \
  --arg scanner "${SCANNER_NAME}" \
  --arg inventory_file "${INVENTORY_FILE}" \
  --arg openbsd_release "${openbsd_release}" \
  --arg errata_url "${errata_url}" \
  --argjson package_count "${pkg_count}" \
  --argjson package_inventory_count "${package_inventory_count}" \
  --argjson inventory_application_count "${inventory_application_count}" \
  --argjson inventory_only_application_count "${inventory_only_application_count}" \
  --argjson unmapped_application_count "${unmapped_application_count}" \
  --argjson enabled_service_count "${enabled_service_count}" \
  --argjson syspatches_installed_count "${syspatches_installed_count}" \
  --argjson component_count "${component_count}" \
  --argjson manual_component_count "${manual_component_count}" \
  --argjson query_errors_total "${query_errors_total}" \
  --argjson mitre_errors_total "${mitre_errors_total}" \
  --argjson mitre_enrichment "$( [ "${MITRE_ENRICH}" = "1" ] && printf 'true' || printf 'false' )" \
  --slurpfile inventory_applications "${INVENTORY_APPLICATIONS_JSON}" \
  --slurpfile inventory_only_applications "${INVENTORY_ONLY_APPLICATIONS_JSON}" \
  --slurpfile unmapped_applications "${UNMAPPED_APPLICATIONS_JSON}" \
  --argjson enabled_services "$(jq -c '.enabled_services // []' "${INVENTORY_FILE}")" \
  --argjson syspatches_installed "$(jq -c '.syspatches_installed // []' "${INVENTORY_FILE}")" \
  --slurpfile components "${COMPONENTS_JSON}" \
  --slurpfile findings "${FINDINGS_JSON}" \
  --slurpfile query_errors "${QUERY_ERRORS_JSON}" \
  --slurpfile mitre_errors "${MITRE_ERRORS_JSON}" \
  --slurpfile active_exceptions "${ACTIVE_EXCEPTIONS_JSON}" \
  --slurpfile expired_exceptions "${EXPIRED_EXCEPTIONS_JSON}" \
  --argjson severity_critical "${severity_critical}" \
  --argjson severity_high "${severity_high}" \
  --argjson severity_medium "${severity_medium}" \
  --argjson severity_low "${severity_low}" \
  --argjson severity_unknown "${severity_unknown}" \
  --arg coverage_note "All structured application inventory entries stay visible in the report; only entries with a non-empty CPE are queried against NVD." \
  --arg record_note "NVD supplies CPE-based vulnerability matching and scoring; MITRE enrichment is best-effort per CVE ID, and contextual applicability still requires operator review." \
  --argjson exceptions_total "${active_total}" \
  --argjson exceptions_expired "${expired_total}" \
  --argjson exceptions_invalid "${invalid_total}" \
  '{
    schema_version: 4,
    scanner: $scanner,
    generated_at: $generated_at,
    inventory_file: $inventory_file,
    openbsd_release: $openbsd_release,
    errata_url: $errata_url,
    package_count: $package_count,
    package_inventory_count: $package_inventory_count,
    enabled_service_count: $enabled_service_count,
    syspatches_installed_count: $syspatches_installed_count,
    inventory_application_count: $inventory_application_count,
    inventory_only_application_count: $inventory_only_application_count,
    unmapped_application_count: $unmapped_application_count,
    component_count: $component_count,
    manual_component_count: $manual_component_count,
    severity_counts: {
      critical: $severity_critical,
      high: $severity_high,
      medium: $severity_medium,
      low: $severity_low,
      unknown: $severity_unknown
    },
    notes: [$coverage_note, $record_note],
    mitre_enrichment: $mitre_enrichment,
    query_errors_total: $query_errors_total,
    mitre_errors_total: $mitre_errors_total,
    enabled_services: $enabled_services,
    syspatches_installed: $syspatches_installed,
    inventory_applications: $inventory_applications[0],
    inventory_only_applications: $inventory_only_applications[0],
    unmapped_applications: $unmapped_applications[0],
    components: $components[0],
    findings: $findings[0],
    query_errors: $query_errors[0],
    mitre_errors: $mitre_errors[0],
    exceptions: {
      total: $exceptions_total,
      expired: $exceptions_expired,
      invalid: $exceptions_invalid,
      active: $active_exceptions[0],
      expired_items: $expired_exceptions[0]
    }
  }' > "${JSON_OUT}"

{
  echo "SBOM mapped scan report"
  echo "generated_at=${generated_at}"
  echo "scanner=${SCANNER_NAME}"
  echo "inventory=${INVENTORY_FILE}"
  echo "openbsd_release=${openbsd_release}"
  [ -n "${errata_url}" ] && echo "errata_url=${errata_url}"
  echo "package_count=${pkg_count}"
  echo "package_inventory_count=${package_inventory_count}"
  echo "enabled_service_count=${enabled_service_count}"
  echo "syspatches_installed_count=${syspatches_installed_count}"
  echo "inventory_application_count=${inventory_application_count}"
  echo "inventory_only_application_count=${inventory_only_application_count}"
  echo "unmapped_application_count=${unmapped_application_count}"
  echo "component_count=${component_count}"
  echo "manual_component_count=${manual_component_count}"
  echo "severity=critical:${severity_critical} high:${severity_high} medium:${severity_medium} low:${severity_low} unknown:${severity_unknown}"
  echo "findings_total=${findings_total}"
  echo "exceptions_total=${active_total}"
  echo "exceptions_expired=${expired_total}"
  echo "exceptions_invalid=${invalid_total}"
  echo "query_errors_total=${query_errors_total}"
  echo "mitre_enrichment=${MITRE_ENRICH}"
  echo "mitre_errors_total=${mitre_errors_total}"
  echo "coverage=all applications stay inventoried; only non-empty CPE entries are queried against NVD"
  echo "applicability=operator review required for contextual applicability of CPE-based matches"

  echo
  echo "enabled services:"
  if [ "${enabled_service_count}" -gt 0 ]; then
    jq -r '.enabled_services[]? | "- \(.)"' "${INVENTORY_FILE}"
  else
    echo "- none"
  fi

  echo
  echo "installed syspatches:"
  if [ "${syspatches_installed_count}" -gt 0 ]; then
    jq -r '.syspatches_installed[]? | "- \(.)"' "${INVENTORY_FILE}"
  else
    echo "- none"
  fi

  echo
  echo "components scanned:"
  if [ "${component_count}" -gt 0 ]; then
    jq -r '.[] | "- \(.component) \(.installed_version) origin=\(.origin) cpe=\(.cpe)"' "${COMPONENTS_JSON}"
  else
    echo "- none"
  fi

  echo
  echo "inventory-only applications:"
  if [ "${inventory_only_application_count}" -gt 0 ]; then
    jq -r '.[] | "- \(.component) \(.installed_version) origin=\(.origin) package=\(.installed_package)"' "${INVENTORY_ONLY_APPLICATIONS_JSON}"
  else
    echo "- none"
  fi

  echo
  echo "unexpected unmapped applications:"
  if [ "${unmapped_application_count}" -gt 0 ]; then
    jq -r '.[] | "- \(.component) \(.installed_version) origin=\(.origin) package=\(.installed_package)"' "${UNMAPPED_APPLICATIONS_JSON}"
  else
    echo "- none"
  fi

  echo
  echo "findings:"
  if [ "${findings_total}" -gt 0 ]; then
    jq -r '.[] | "- \(.cve_id) severity=\(.severity) score=\(.score) component=\(.component) version=\(.installed_version) excepted=\(.excepted)"' "${FINDINGS_JSON}"
  else
    echo "- none"
  fi

  if [ "${query_errors_total}" -gt 0 ]; then
    echo
    echo "query errors:"
    jq -r '.[] | "- stage=\(.stage) component=\(.component // "n/a") cpe=\(.cpe // "n/a")"' "${QUERY_ERRORS_JSON}"
  fi

  if [ "${mitre_errors_total}" -gt 0 ]; then
    echo
    echo "mitre enrichment errors:"
    jq -r '.[] | "- cve=\(.cve_id)"' "${MITRE_ERRORS_JSON}"
  fi
} > "${TXT_OUT}"

echo "ok: wrote ${JSON_OUT}"
echo "ok: wrote ${TXT_OUT}"
