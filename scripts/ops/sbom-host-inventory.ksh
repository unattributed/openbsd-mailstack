#!/bin/ksh
REPO_ROOT_DEFAULT="$(cd "$(dirname "$0")/../.." && pwd -P)"
# =============================================================================
# sbom/bin/sbom-host-inventory.ksh
# =============================================================================
# Summary:
#   generate host package inventory JSON using OpenBSD pkg_info output and
#   structured application components for mapped SBOM scanning.
#
# Usage:
#   sbom-host-inventory.ksh [--repo <path>] [--out <path>] [--host <name>] \
#     [--cpe-map <path>] [--manual-components <path>]
# =============================================================================

set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

REPO_ROOT="${REPO_ROOT_DEFAULT}"
HOST_NAME="$(hostname)"
OUT_FILE=""
CPE_MAP_FILE=""
MANUAL_COMPONENTS_FILE=""
POSTFIXADMIN_CONFIG_FILE="${SBOM_POSTFIXADMIN_CONFIG_FILE:-/var/www/postfixadmin/config.inc.php}"
TAB="$(printf '\t')"

usage() {
  cat <<'USAGE' >&2
usage: sbom-host-inventory.ksh [--repo <path>] [--out <path>] [--host <name>] [--cpe-map <path>] [--manual-components <path>]
USAGE
  exit 2
}

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

replace_version_token() {
  awk -v tmpl="$1" -v version="$2" 'BEGIN { gsub(/%VERSION%/, version, tmpl); printf "%s", tmpl }'
}

emit_component_json() {
  _scan_eligible=false
  _inventory_only=false
  [ -n "$4" ] && _scan_eligible=true
  [ "${7:-false}" = "true" ] && _inventory_only=true
  printf '%s' "{\"origin\":\"$(json_escape "$1")\",\"component\":\"$(json_escape "$2")\",\"installed_version\":\"$(json_escape "$3")\",\"cpe\":\"$(json_escape "$4")\",\"installed_package\":\"$(json_escape "$5")\",\"note\":\"$(json_escape "$6")\",\"scan_eligible\":${_scan_eligible},\"inventory_only\":${_inventory_only}}"
}

emit_package_inventory_json() {
  _line="$1"
  _pkg="${_line%% *}"
  _desc="${_line#${_pkg}}"
  [ "${_desc}" = "${_line}" ] && _desc=""
  _desc="$(printf '%s' "${_desc}" | sed 's/^[[:space:]]*//')"
  printf '%s' "{\"package\":\"$(json_escape "${_pkg}")\",\"description\":\"$(json_escape "${_desc}")\"}"
}

register_component() {
  _origin="$1"
  _component="$2"
  _version="$3"
  _cpe="$4"
  _installed_package="$5"
  _note="$6"
  _inventory_only="${7:-false}"
  _key="${_component}|${_version}|${_cpe}|${_installed_package}|${_inventory_only}"

  if grep -qxF "${_key}" "${TMP_COMPONENT_KEYS}" 2>/dev/null; then
    return 0
  fi

  printf '%s\n' "${_key}" >> "${TMP_COMPONENT_KEYS}"
  emit_component_json "${_origin}" "${_component}" "${_version}" "${_cpe}" "${_installed_package}" "${_note}" "${_inventory_only}" >> "${TMP_COMPONENTS}"
  echo >> "${TMP_COMPONENTS}"
}

detect_php_bin() {
  if [ -n "${PHP_BIN:-}" ] && command -v "${PHP_BIN}" >/dev/null 2>&1; then
    command -v "${PHP_BIN}"
    return 0
  fi
  if [ -x /usr/local/bin/php ]; then
    printf '%s\n' /usr/local/bin/php
    return 0
  fi
  _php_candidate="$(ls -1 /usr/local/bin/php-[0-9].[0-9] 2>/dev/null | sort | tail -1 || true)"
  [ -n "${_php_candidate}" ] && [ -x "${_php_candidate}" ] || return 1
  printf '%s\n' "${_php_candidate}"
}

probe_postfixadmin_component() {
  [ -r "${POSTFIXADMIN_CONFIG_FILE}" ] || return 0
  _php_bin="$(detect_php_bin || true)"
  [ -n "${_php_bin}" ] || return 0
  _version="$("${_php_bin}" -r "require '${POSTFIXADMIN_CONFIG_FILE}'; echo isset(\$CONF['version']) ? \$CONF['version'] : '';" 2>/dev/null | tr -d '\r' | head -n 1 || true)"
  [ -n "${_version}" ] || return 0
  register_component \
    "source_runtime" \
    "postfixadmin" \
    "${_version}" \
    "cpe:2.3:a:postfixadmin:postfixadmin:${_version}:*:*:*:*:*:*:*" \
    "postfixadmin" \
    "Detected from ${POSTFIXADMIN_CONFIG_FILE}"
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
    --host)
      [ $# -ge 2 ] || usage
      HOST_NAME="$2"
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
    --help|-h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

command -v pkg_info >/dev/null 2>&1 || {
  echo "error: pkg_info not found (OpenBSD host required)" >&2
  exit 1
}

[ -n "${OUT_FILE}" ] || OUT_FILE="${REPO_ROOT}/services/generated/sbom/host-inventory-${HOST_NAME}.json"
[ -n "${CPE_MAP_FILE}" ] || CPE_MAP_FILE="${REPO_ROOT}/services/sbom/components/cpe-map.tsv"
[ -n "${MANUAL_COMPONENTS_FILE}" ] || MANUAL_COMPONENTS_FILE="${REPO_ROOT}/services/sbom/components/manual-components.tsv"

TMP_PKGS="/tmp/sbom-host-pkgs.$$"
TMP_PKG_LINES="/tmp/sbom-host-pkg-lines.$$"
TMP_COMPONENT_KEYS="/tmp/sbom-host-components-keys.$$"
TMP_COMPONENTS="/tmp/sbom-host-components.$$"
TMP_ENABLED_SERVICES="/tmp/sbom-host-enabled-services.$$"
TMP_SYSPATCHES_INSTALLED="/tmp/sbom-host-syspatches-installed.$$"
trap 'rm -f "${TMP_PKGS}" "${TMP_PKG_LINES}" "${TMP_COMPONENT_KEYS}" "${TMP_COMPONENTS}" "${TMP_ENABLED_SERVICES}" "${TMP_SYSPATCHES_INSTALLED}"' EXIT INT TERM
: > "${TMP_COMPONENT_KEYS}"
: > "${TMP_COMPONENTS}"
: > "${TMP_ENABLED_SERVICES}"
: > "${TMP_SYSPATCHES_INSTALLED}"

# Inventory all installed packages and preserve descriptions for full host tracking.
pkg_info -a | sort -u > "${TMP_PKG_LINES}"
awk '{print $1}' "${TMP_PKG_LINES}" | sort -u > "${TMP_PKGS}"
count="$(wc -l < "${TMP_PKGS}" | awk '{print $1}')"
created="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
openbsd_release="$(uname -r 2>/dev/null || true)"
release_slug="$(printf '%s' "${openbsd_release}" | tr -d '.')"
errata_url=""
[ -n "${release_slug}" ] && errata_url="https://www.openbsd.org/errata${release_slug}.html"

if command -v rcctl >/dev/null 2>&1; then
  rcctl ls on 2>/dev/null | sort -u > "${TMP_ENABLED_SERVICES}" || true
fi
enabled_service_count="$(awk 'NF{c++} END{print c+0}' "${TMP_ENABLED_SERVICES}")"

if command -v syspatch >/dev/null 2>&1; then
  syspatch -l 2>/dev/null | sort -u > "${TMP_SYSPATCHES_INSTALLED}" || true
fi
syspatches_installed_count="$(awk 'NF{c++} END{print c+0}' "${TMP_SYSPATCHES_INSTALLED}")"

if [ -r "${CPE_MAP_FILE}" ]; then
  while IFS= read -r pkg; do
    [ -n "${pkg}" ] || continue
    while IFS="${TAB}" read -r match_regex component cpe_template note; do
      case "${match_regex}" in
        ''|\#*) continue ;;
      esac
      version="$(printf '%s\n' "${pkg}" | sed -En "s~${match_regex}~\\1~p" | head -n 1 || true)"
      if [ -n "${version}" ]; then
        inventory_only=false
        cpe="$(replace_version_token "${cpe_template}" "${version}")"
        if [ "${cpe}" = "inventory_only" ]; then
          cpe=""
          inventory_only=true
        fi
        register_component "inventory" "${component}" "${version}" "${cpe}" "${pkg}" "${note}" "${inventory_only}"
        break
      fi
    done < "${CPE_MAP_FILE}"
  done < "${TMP_PKGS}"
fi

probe_postfixadmin_component

if [ -r "${MANUAL_COMPONENTS_FILE}" ]; then
  while IFS="${TAB}" read -r component version cpe note; do
    case "${component}" in
      ''|\#*) continue ;;
    esac
    [ -n "${version}" ] || continue
    inventory_only=false
    if [ "${cpe}" = "inventory_only" ]; then
      cpe=""
      inventory_only=true
    fi
    register_component "manual_manifest" "${component}" "${version}" "${cpe}" "${component}" "${note:-manual component manifest}" "${inventory_only}"
  done < "${MANUAL_COMPONENTS_FILE}"
fi

application_count="$(awk 'NF{c++} END{print c+0}' "${TMP_COMPONENTS}")"

install -d -m 0755 "$(dirname "${OUT_FILE}")"

{
  echo "{"
  echo "  \"schema_version\": 1,"
  echo "  \"host\": \"$(json_escape "${HOST_NAME}")\","
  echo "  \"generated_at\": \"${created}\","
  echo "  \"openbsd_release\": \"$(json_escape "${openbsd_release}")\","
  echo "  \"errata_url\": \"$(json_escape "${errata_url}")\","
  echo "  \"package_count\": ${count},"
  echo "  \"packages\": ["

  first=1
  while IFS= read -r pkg; do
    [ -n "${pkg}" ] || continue
    esc_pkg="$(json_escape "${pkg}")"
    if [ "${first}" -eq 0 ]; then
      printf ',\n'
    fi
    first=0
    printf '    "%s"' "${esc_pkg}"
  done < "${TMP_PKGS}"

  echo
  echo "  ],"
  echo "  \"package_inventory\": ["

  first=1
  while IFS= read -r pkg_line; do
    [ -n "${pkg_line}" ] || continue
    if [ "${first}" -eq 0 ]; then
      printf ',\n'
    fi
    first=0
    printf '    %s' "$(emit_package_inventory_json "${pkg_line}")"
  done < "${TMP_PKG_LINES}"

  echo
  echo "  ],"
  echo "  \"enabled_service_count\": ${enabled_service_count},"
  echo "  \"enabled_services\": ["

  first=1
  while IFS= read -r svc; do
    [ -n "${svc}" ] || continue
    if [ "${first}" -eq 0 ]; then
      printf ',\n'
    fi
    first=0
    printf '    "%s"' "$(json_escape "${svc}")"
  done < "${TMP_ENABLED_SERVICES}"

  echo
  echo "  ],"
  echo "  \"syspatches_installed_count\": ${syspatches_installed_count},"
  echo "  \"syspatches_installed\": ["

  first=1
  while IFS= read -r patch_id; do
    [ -n "${patch_id}" ] || continue
    if [ "${first}" -eq 0 ]; then
      printf ',\n'
    fi
    first=0
    printf '    "%s"' "$(json_escape "${patch_id}")"
  done < "${TMP_SYSPATCHES_INSTALLED}"

  echo
  echo "  ],"
  echo "  \"application_count\": ${application_count},"
  echo "  \"applications\": ["

  if [ -s "${TMP_COMPONENTS}" ]; then
    awk 'BEGIN { first=1 } /^\s*$/ { next } { if (first==0) printf ",\n"; printf "    %s", $0; first=0 }' "${TMP_COMPONENTS}"
  fi

  echo
  echo "  ]"
  echo "}"
} > "${OUT_FILE}"

echo "ok: wrote ${OUT_FILE}"
