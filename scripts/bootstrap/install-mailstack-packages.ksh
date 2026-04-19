#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing shared library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

: "${OPENBSD_VERSION:=7.8}"
: "${OPENBSD_MAILSTACK_PACKAGE_LIST:=
postfix-3.10.1p3v0-mysql
mariadb-server-11.4.7v1
mariadb-client-11.4.7v1
dovecot-2.3.21.1p1v0
dovecot-mysql-2.3.21.1p1v0
dovecot-pigeonhole-0.5.21.1v1
redis-6.2.20
rspamd-3.13.1
nginx-1.28.0p1
php-8.3.26p1
php-cgi-8.3.26p0
php-pdo_mysql-8.3.26p0
php-mysqli-8.3.26p0
php-imap-8.3.26p0
php-intl-8.3.26p0
php-gd-8.3.26p0
php-curl-8.3.26p0
roundcubemail-1.6.11p0
clamav-1.4.3
curl
rsync
jq
git
git-lfs
}" 

usage() {
  cat <<'USAGE'
usage: install-mailstack-packages.ksh [--package LIST] [--dry-run]
USAGE
}

DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --package)
      [ "$#" -ge 2 ] || die "missing value for --package"
      OPENBSD_MAILSTACK_PACKAGE_LIST="${OPENBSD_MAILSTACK_PACKAGE_LIST} ${2}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

ensure_installurl() {
  if [ ! -s /etc/installurl ]; then
    print -- "https://cdn.openbsd.org/pub/OpenBSD" > /etc/installurl
  fi
}

pkg_path_for_release() {
  _base="$(cat /etc/installurl 2>/dev/null || true)"
  [ -n "${_base}" ] || die "unable to determine installurl"
  print -- "${_base}/${OPENBSD_VERSION}/packages/$(machine -a 2>/dev/null || uname -m)"
}

install_package_list() {
  _pkg_path="$(pkg_path_for_release)"
  log_info "using package path: ${_pkg_path}"

  print -- "${OPENBSD_MAILSTACK_PACKAGE_LIST}" | awk 'NF {print $1}' | while IFS= read -r _pkg; do
    [ -n "${_pkg}" ] || continue
    if pkg_info -e "${_pkg}" >/dev/null 2>&1; then
      log_info "already installed: ${_pkg}"
      continue
    fi
    if [ "${DRY_RUN}" = "1" ]; then
      log_info "dry run would install: ${_pkg}"
      continue
    fi
    log_info "installing package: ${_pkg}"
    env PKG_PATH="${_pkg_path}" pkg_add -I "${_pkg}" || die "failed to install package: ${_pkg}"
  done
}

print_notes() {
  print
  print -- "Package bootstrap notes"
  print -- "  - This script installs the core package baseline for the QEMU lab proof."
  print -- "  - It intentionally does not attempt to source-install PostfixAdmin."
  print -- "  - Review package versions when moving from 7.8 release packages to packages-stable or snapshots."
  print
}

main() {
  ensure_openbsd
  ensure_openbsd_version "${OPENBSD_VERSION}"
  require_command pkg_add
  require_command pkg_info
  require_command machine
  ensure_installurl
  install_package_list
  print_notes
}

main "$@"
