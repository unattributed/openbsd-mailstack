#!/bin/ksh
REPO_ROOT_DEFAULT="$(cd "$(dirname "$0")/../.." && pwd -P)"
# =============================================================================
# sbom/bin/sbom-scan-openbsd-fallback.ksh
# =============================================================================
# Summary:
#   generate fallback vulnerability scan report for OpenBSD package inventory.
#
# Notes:
#   - This scanner does not map CVEs; severity counts default to zero.
#   - Exception expiry tracking is enforced via exceptions.tsv.
#
# Usage:
#   sbom-scan-openbsd-fallback.ksh [--repo <path>] [--inventory <path>] \
#     [--exceptions <path>] [--json-out <path>] [--txt-out <path>]
# =============================================================================

set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

REPO_ROOT="${REPO_ROOT_DEFAULT}"
HOST_NAME="$(hostname)"
INVENTORY_FILE=""
EXCEPTIONS_FILE=""
JSON_OUT=""
TXT_OUT=""

usage() {
  cat <<'USAGE' >&2
usage: sbom-scan-openbsd-fallback.ksh [--repo <path>] [--inventory <path>] [--exceptions <path>] [--json-out <path>] [--txt-out <path>]
USAGE
  exit 2
}

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

emit_exception_json() {
  _id="$1"
  _pkg="$2"
  _reason="$3"
  _owner="$4"
  _expires="$5"

  printf '%s' "{\"id\":\"$(json_escape "${_id}")\",\"package\":\"$(json_escape "${_pkg}")\",\"reason\":\"$(json_escape "${_reason}")\",\"owner\":\"$(json_escape "${_owner}")\",\"expires_on\":\"$(json_escape "${_expires}")\"}"
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
    --help|-h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

[ -n "${INVENTORY_FILE}" ] || INVENTORY_FILE="${REPO_ROOT}/services/generated/sbom/host-inventory-${HOST_NAME}.json"
[ -n "${EXCEPTIONS_FILE}" ] || EXCEPTIONS_FILE="${REPO_ROOT}/services/sbom/exceptions/exceptions.tsv"
[ -n "${JSON_OUT}" ] || JSON_OUT="${REPO_ROOT}/services/generated/sbom/scan-report.json"
[ -n "${TXT_OUT}" ] || TXT_OUT="${REPO_ROOT}/services/generated/sbom/scan-report.txt"

[ -f "${INVENTORY_FILE}" ] || {
  echo "error: inventory file not found: ${INVENTORY_FILE}" >&2
  exit 1
}

[ -f "${EXCEPTIONS_FILE}" ] || {
  echo "error: exceptions file not found: ${EXCEPTIONS_FILE}" >&2
  exit 1
}

pkg_count="$(awk -F: '/"package_count"[[:space:]]*:/ {gsub(/[^0-9]/, "", $2); print $2; exit}' "${INVENTORY_FILE}")"
[ -n "${pkg_count}" ] || pkg_count=0

TMP_ACTIVE="/tmp/sbom-exc-active.$$"
TMP_EXPIRED="/tmp/sbom-exc-expired.$$"
trap 'rm -f "${TMP_ACTIVE}" "${TMP_EXPIRED}"' EXIT INT TERM
: > "${TMP_ACTIVE}"
: > "${TMP_EXPIRED}"

today="$(date +%Y-%m-%d)"
active_total=0
expired_total=0
invalid_total=0

while IFS=$'\t' read -r id pkg reason owner expires; do
  case "${id}" in
    ''|\#*) continue ;;
  esac

  if [ -z "${pkg}" ] || [ -z "${reason}" ] || [ -z "${owner}" ] || [ -z "${expires}" ]; then
    invalid_total=$((invalid_total + 1))
    continue
  fi

  active_total=$((active_total + 1))

  if [ "${expires}" \< "${today}" ]; then
    expired_total=$((expired_total + 1))
    emit_exception_json "${id}" "${pkg}" "${reason}" "${owner}" "${expires}" >> "${TMP_EXPIRED}"
    echo >> "${TMP_EXPIRED}"
  fi

  emit_exception_json "${id}" "${pkg}" "${reason}" "${owner}" "${expires}" >> "${TMP_ACTIVE}"
  echo >> "${TMP_ACTIVE}"
done < "${EXCEPTIONS_FILE}"

install -d -m 0755 "$(dirname "${JSON_OUT}")" "$(dirname "${TXT_OUT}")"

active_json=""
expired_json=""

if [ -s "${TMP_ACTIVE}" ]; then
  active_json="$(awk 'BEGIN { first=1 } /^\s*$/ {next} { if (first==0) printf ",\n"; printf "      %s", $0; first=0 }' "${TMP_ACTIVE}")"
fi

if [ -s "${TMP_EXPIRED}" ]; then
  expired_json="$(awk 'BEGIN { first=1 } /^\s*$/ {next} { if (first==0) printf ",\n"; printf "      %s", $0; first=0 }' "${TMP_EXPIRED}")"
fi

generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "${JSON_OUT}" <<EOF_JSON
{
  "schema_version": 1,
  "scanner": "openbsd-native-fallback",
  "generated_at": "${generated_at}",
  "inventory_file": "$(json_escape "${INVENTORY_FILE}")",
  "package_count": ${pkg_count},
  "severity_counts": {
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0,
    "unknown": 0
  },
  "exceptions": {
    "total": ${active_total},
    "expired": ${expired_total},
    "invalid": ${invalid_total},
    "active": [
${active_json}
    ],
    "expired_items": [
${expired_json}
    ]
  }
}
EOF_JSON

{
  echo "SBOM fallback scan report"
  echo "generated_at=${generated_at}"
  echo "scanner=openbsd-native-fallback"
  echo "inventory=${INVENTORY_FILE}"
  echo "package_count=${pkg_count}"
  echo "severity=critical:0 high:0 medium:0 low:0 unknown:0"
  echo "exceptions_total=${active_total}"
  echo "exceptions_expired=${expired_total}"
  echo "exceptions_invalid=${invalid_total}"

  if [ "${expired_total}" -gt 0 ]; then
    echo
    echo "expired exceptions:"
    awk -F'\t' -v today="${today}" '
      $0 ~ /^#/ || NF < 5 { next }
      $5 < today { printf "- %s %s owner=%s expired=%s\n", $1, $2, $4, $5 }
    ' "${EXCEPTIONS_FILE}"
  fi
} > "${TXT_OUT}"

echo "ok: wrote ${JSON_OUT}"
echo "ok: wrote ${TXT_OUT}"
