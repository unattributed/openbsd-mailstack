#!/bin/ksh
REPO_ROOT_DEFAULT="$(cd "$(dirname "$0")/../.." && pwd -P)"
# =============================================================================
# sbom/bin/sbom-source-spdx.ksh
# =============================================================================
# Summary:
#   generate a minimal SPDX 2.3 JSON document from tracked repository files.
#
# Usage:
#   sbom-source-spdx.ksh [--repo <path>] [--out <path>]
# =============================================================================

set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

REPO_ROOT="${REPO_ROOT_DEFAULT}"
OUT_FILE=""

usage() {
  cat <<'USAGE' >&2
usage: sbom-source-spdx.ksh [--repo <path>] [--out <path>]
USAGE
  exit 2
}

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      [ $# -ge 2 ] || usage
      REPO_ROOT="$2"
      shift 2
      ;;
    --out)
      [ $# -ge 2 ] || usage
      OUT_FILE="$2"
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

[ -d "${REPO_ROOT}/.git" ] || {
  echo "error: repo not found at ${REPO_ROOT}" >&2
  exit 1
}

REPO_ROOT="$(cd "${REPO_ROOT}" && pwd -P)"
[ -n "${OUT_FILE}" ] || OUT_FILE="${REPO_ROOT}/services/generated/sbom/source.spdx.json"

TMP_LIST="/tmp/sbom-source-files.$$"
TMP_ENTRIES="/tmp/sbom-source-entries.$$"
trap 'rm -f "${TMP_LIST}" "${TMP_ENTRIES}"' EXIT INT TERM

if ! git -C "${REPO_ROOT}" -c safe.directory="${REPO_ROOT}" ls-files > "${TMP_LIST}"; then
  echo "error: unable to enumerate git files for ${REPO_ROOT}" >&2
  echo "hint: confirm repository ownership and git safe.directory policy" >&2
  exit 1
fi
: > "${TMP_ENTRIES}"

first=1
idx=1
while IFS= read -r relpath; do
  [ -n "${relpath}" ] || continue
  fullpath="${REPO_ROOT}/${relpath}"
  [ -f "${fullpath}" ] || continue

  checksum="$(sha256 -q "${fullpath}")"
  esc_path="$(json_escape "${relpath}")"

  if [ "${first}" -eq 0 ]; then
    printf ',\n' >> "${TMP_ENTRIES}"
  fi
  first=0

  cat >> "${TMP_ENTRIES}" <<ENTRY
    {
      "SPDXID": "SPDXRef-File-${idx}",
      "fileName": "${esc_path}",
      "checksums": [
        {
          "algorithm": "SHA256",
          "checksumValue": "${checksum}"
        }
      ],
      "licenseConcluded": "NOASSERTION",
      "copyrightText": "NOASSERTION"
    }
ENTRY

  idx=$((idx + 1))
done < "${TMP_LIST}"

created="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
namespace_ts="$(date -u +"%Y%m%dT%H%M%SZ")"

install -d -m 0755 "$(dirname "${OUT_FILE}")"

cat > "${OUT_FILE}" <<EOF_JSON
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": "openbsd-mailstack-source",
  "documentNamespace": "https://example.invalid/spdx/openbsd-mailstack/${namespace_ts}",
  "creationInfo": {
    "created": "${created}",
    "creators": [
      "Tool: sbom-source-spdx.ksh"
    ]
  },
  "files": [
$(cat "${TMP_ENTRIES}")
  ]
}
EOF_JSON

echo "ok: wrote ${OUT_FILE}"
