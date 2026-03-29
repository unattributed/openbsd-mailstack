#!/bin/ksh
REPO_ROOT_DEFAULT="$(cd "$(dirname "$0")/../.." && pwd -P)"
# =============================================================================
# sbom/bin/sbom-daily-scan.ksh
# =============================================================================
# Summary:
#   daily SBOM generation and scan pipeline.
#
# Usage:
#   sbom-daily-scan.ksh [--repo <path>] [--host <hostname>] \
#     [--scanner auto|mapped|fallback]
# =============================================================================

set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

REPO_ROOT="${REPO_ROOT_DEFAULT}"
HOST_NAME="$(hostname)"
SCANNER_MODE="${SBOM_SCANNER_MODE:-auto}"

usage() {
  cat <<'USAGE' >&2
usage: sbom-daily-scan.ksh [--repo <path>] [--host <hostname>] [--scanner auto|mapped|fallback]
USAGE
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      [ $# -ge 2 ] || usage
      REPO_ROOT="$2"
      shift 2
      ;;
    --host)
      [ $# -ge 2 ] || usage
      HOST_NAME="$2"
      shift 2
      ;;
    --scanner)
      [ $# -ge 2 ] || usage
      SCANNER_MODE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

json_string_key() {
  _f="$1"
  _key="$2"
  _v=""
  [ -r "${_f}" ] || {
    printf 'unknown\n'
    return 0
  }
  _v="$(sed -n "s/.*\"${_key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "${_f}" 2>/dev/null | head -n 1 || true)"
  [ -n "${_v}" ] && printf '%s\n' "${_v}" || printf 'unknown\n'
}

json_number_key() {
  _f="$1"
  _key="$2"
  _v=""
  [ -r "${_f}" ] || {
    printf '0\n'
    return 0
  }
  _v="$(sed -n "s/.*\"${_key}\"[[:space:]]*:[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" "${_f}" 2>/dev/null | head -n 1 || true)"
  [ -n "${_v}" ] && printf '%s\n' "${_v}" || printf '0\n'
}

resolve_tool() {
  _tool="$1"
  if [ -x "${SCRIPT_DIR}/${_tool}" ]; then
    printf '%s\n' "${SCRIPT_DIR}/${_tool}"
    return 0
  fi
  if [ -x "/usr/local/sbin/${_tool}" ]; then
    printf '%s\n' "/usr/local/sbin/${_tool}"
    return 0
  fi
  echo "error: tool not found: ${_tool}" >&2
  exit 1
}

resolve_optional_tool() {
  _tool="$1"
  if [ -x "${SCRIPT_DIR}/${_tool}" ]; then
    printf '%s\n' "${SCRIPT_DIR}/${_tool}"
    return 0
  fi
  if [ -x "/usr/local/sbin/${_tool}" ]; then
    printf '%s\n' "/usr/local/sbin/${_tool}"
    return 0
  fi
  return 1
}

select_scan_tool() {
  _fallback_tool="$(resolve_tool sbom-scan-openbsd-fallback.ksh)"
  _mapped_tool="$(resolve_optional_tool sbom-scan-nvd-mapped.ksh || true)"

  case "${SCANNER_MODE}" in
    fallback)
      printf '%s\n' "${_fallback_tool}"
      ;;
    mapped)
      [ -n "${_mapped_tool}" ] || {
        echo "error: mapped scanner requested but sbom-scan-nvd-mapped.ksh is not installed" >&2
        exit 1
      }
      printf '%s\n' "${_mapped_tool}"
      ;;
    auto)
      if [ -n "${_mapped_tool}" ] && command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        printf '%s\n' "${_mapped_tool}"
      else
        printf '%s\n' "${_fallback_tool}"
      fi
      ;;
    *)
      echo "error: unsupported scanner mode: ${SCANNER_MODE}" >&2
      exit 1
      ;;
  esac
}

SRC_TOOL="$(resolve_tool sbom-source-spdx.ksh)"
INV_TOOL="$(resolve_tool sbom-host-inventory.ksh)"
SCAN_TOOL="$(select_scan_tool)"

SOURCE_FILE="${REPO_ROOT}/services/generated/sbom/source.spdx.json"
INVENTORY_FILE="${REPO_ROOT}/services/generated/sbom/host-inventory-${HOST_NAME}.json"
REPORT_JSON="${REPO_ROOT}/services/generated/sbom/scan-report.json"
REPORT_TXT="${REPO_ROOT}/services/generated/sbom/scan-report.txt"
EXCEPTIONS_FILE="${REPO_ROOT}/services/sbom/exceptions/exceptions.tsv"

ksh "${SRC_TOOL}" --repo "${REPO_ROOT}" --out "${SOURCE_FILE}"
ksh "${INV_TOOL}" --repo "${REPO_ROOT}" --host "${HOST_NAME}" --out "${INVENTORY_FILE}"
ksh "${SCAN_TOOL}" --repo "${REPO_ROOT}" --inventory "${INVENTORY_FILE}" --exceptions "${EXCEPTIONS_FILE}" --json-out "${REPORT_JSON}" --txt-out "${REPORT_TXT}"

scanner="$(json_string_key "${REPORT_JSON}" scanner)"
exceptions_expired="$(json_number_key "${REPORT_JSON}" expired)"
exceptions_invalid="$(json_number_key "${REPORT_JSON}" invalid)"
query_errors_total="$(json_number_key "${REPORT_JSON}" query_errors_total)"
inventory_only_application_count="$(json_number_key "${REPORT_JSON}" inventory_only_application_count)"
unmapped_application_count="$(json_number_key "${REPORT_JSON}" unmapped_application_count)"
semantic_note=""
capability_note=""
coverage_note=""
if [ "${scanner}" = "openbsd-native-fallback" ]; then
  capability_note="scanner=${scanner} inventory_only no_cve_mapping"
fi
if [ "${exceptions_expired}" -gt 0 ]; then
  [ -n "${semantic_note}" ] && semantic_note="${semantic_note}; "
  semantic_note="${semantic_note}expired_exceptions=${exceptions_expired}"
fi
if [ "${exceptions_invalid}" -gt 0 ]; then
  [ -n "${semantic_note}" ] && semantic_note="${semantic_note}; "
  semantic_note="${semantic_note}invalid_exceptions=${exceptions_invalid}"
fi
if [ "${query_errors_total}" -gt 0 ]; then
  [ -n "${semantic_note}" ] && semantic_note="${semantic_note}; "
  semantic_note="${semantic_note}query_errors=${query_errors_total}"
fi
if [ "${inventory_only_application_count}" -gt 0 ]; then
  coverage_note="inventory_only_apps=${inventory_only_application_count}"
fi
if [ "${unmapped_application_count}" -gt 0 ]; then
  [ -n "${semantic_note}" ] && semantic_note="${semantic_note}; "
  semantic_note="${semantic_note}unmapped_apps=${unmapped_application_count}"
fi

echo "ok: daily sbom pipeline complete"
echo "source=${SOURCE_FILE}"
echo "inventory=${INVENTORY_FILE}"
echo "report_json=${REPORT_JSON}"
echo "report_txt=${REPORT_TXT}"
if [ -n "${capability_note}" ]; then
  echo "note: ${capability_note}"
fi
if [ -n "${semantic_note}" ]; then
  echo "CRON_REPORT_STATUS=WARN"
  report_note="${semantic_note}"
  if [ -n "${capability_note}" ]; then
    report_note="${capability_note}; ${report_note}"
  fi
  if [ -n "${coverage_note}" ]; then
    report_note="${report_note}; ${coverage_note}"
  fi
  echo "CRON_REPORT_NOTE=${report_note}"
elif [ -n "${capability_note}" ] || [ -n "${coverage_note}" ]; then
  report_note="${capability_note}"
  if [ -n "${coverage_note}" ]; then
    if [ -n "${report_note}" ]; then
      report_note="${report_note}; ${coverage_note}"
    else
      report_note="${coverage_note}"
    fi
  fi
  echo "CRON_REPORT_NOTE=${report_note}"
fi
