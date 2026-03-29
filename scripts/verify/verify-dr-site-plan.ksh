#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"
. "${COMMON_LIB}"

load_project_config
prompt_value "DR_SITE_SERVER_NAME" "Enter the DR site server name" "${DR_SITE_SERVER_NAME:-dr.example.com}"
prompt_value "DR_SITE_OPERATOR_EMAIL" "Enter the DR site operator email" "${DR_SITE_OPERATOR_EMAIL:-ops@example.com}"
prompt_value "DR_SITE_PUBLISH_ROOT" "Enter the DR site publish root" "${DR_SITE_PUBLISH_ROOT:-/var/www/htdocs/dr}"
prompt_value "DR_HOST_BASE_ROOT" "Enter the DR host base root" "${DR_HOST_BASE_ROOT:-/srv/openbsd-mailstack-dr}"

validate_hostname "${DR_SITE_SERVER_NAME}" || die "invalid DR_SITE_SERVER_NAME: ${DR_SITE_SERVER_NAME}"
validate_email "${DR_SITE_OPERATOR_EMAIL}" || die "invalid DR_SITE_OPERATOR_EMAIL: ${DR_SITE_OPERATOR_EMAIL}"
validate_absolute_path "${DR_SITE_PUBLISH_ROOT}" || die "invalid DR_SITE_PUBLISH_ROOT: ${DR_SITE_PUBLISH_ROOT}"
validate_absolute_path "${DR_HOST_BASE_ROOT}" || die "invalid DR_HOST_BASE_ROOT: ${DR_HOST_BASE_ROOT}"

for _file in   "${PROJECT_ROOT}/maint/dr-site/README.md"   "${PROJECT_ROOT}/maint/dr-site/provisioning/README.md"   "${PROJECT_ROOT}/maint/dr-site/nginx/dr-site.locations.template"   "${PROJECT_ROOT}/maint/dr-site/htdocs/index.html"   "${PROJECT_ROOT}/maint/dr-site/htdocs/runbook.html"   "${PROJECT_ROOT}/maint/dr-site/htdocs/sysadmin.html"   "${PROJECT_ROOT}/maint/dr-site/assets/dr.css"   "${PROJECT_ROOT}/maint/dr-site/assets/dr.js"   "${PROJECT_ROOT}/scripts/install/provision-dr-site-host.ksh"; do
  [ -f "${_file}" ] || die "missing DR site asset: ${_file}"
done

print -- "PASS DR site planning assets are present"
