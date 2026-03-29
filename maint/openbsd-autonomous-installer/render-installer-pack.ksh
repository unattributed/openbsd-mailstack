#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE=""
PROFILE_NAME=""
BUILD_ROOT="${SCRIPT_DIR}/build"

usage() {
  cat <<'USAGE'
usage: render-installer-pack.ksh --profile path/to/profile.env
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[ -n "${PROFILE}" ] || { usage >&2; exit 1; }
[ -r "${PROFILE}" ] || { echo "profile not readable: ${PROFILE}" >&2; exit 1; }

. "${PROFILE}"

: "${PROFILE_NAME:=default}"
: "${OPENBSD_VERSION:=7.8}"
: "${SYSTEM_HOSTNAME:=mail.example.com}"
: "${DNS_DOMAIN:=example.com}"
: "${TIMEZONE:=UTC}"
: "${OPERATOR_USER:=foo}"
: "${OPERATOR_HOME:=/home/${OPERATOR_USER}}"
: "${ROOT_PASSWORD_BCRYPT:?ROOT_PASSWORD_BCRYPT must be set in profile}"
: "${PARROT_PUBKEY:?PARROT_PUBKEY must be set in profile}"
: "${LAN_IF_DEFAULT:=em0}"
: "${LAN_NET_DEFAULT:=192.168.1.0/24}"
: "${HOST_IP_DEFAULT:=192.168.1.44}"
: "${HOST_IP_CIDR_REAL:=192.168.1.44/24}"
: "${HOST_GATEWAY_DEFAULT:=192.168.1.1}"
: "${NAMESERVER_DEFAULT:=1.1.1.1}"
: "${AUTOINSTALL_HTTP_HOST:=PARROT_IP}"
: "${AUTOINSTALL_HTTP_PORT:=8000}"
: "${MAILSTACK_REPO_CLONE_URL:=https://github.com/unattributed/openbsd-mailstack}"

OUT_DIR="${BUILD_ROOT}/${PROFILE_NAME}"
SITE_ROOT="${OUT_DIR}/site78_root"
mkdir -p "${OUT_DIR}" "${SITE_ROOT}/root"

render_template() {
  in_file="$1"
  out_file="$2"
  sed     -e "s|__SYSTEM_HOSTNAME__|${SYSTEM_HOSTNAME}|g"     -e "s|__DNS_DOMAIN__|${DNS_DOMAIN}|g"     -e "s|__ROOT_PASSWORD_BCRYPT__|${ROOT_PASSWORD_BCRYPT}|g"     -e "s|__OPERATOR_USER__|${OPERATOR_USER}|g"     -e "s|__OPERATOR_HOME__|${OPERATOR_HOME}|g"     -e "s|__PARROT_PUBKEY__|${PARROT_PUBKEY}|g"     -e "s|__TIMEZONE__|${TIMEZONE}|g"     -e "s|__LAN_IF_DEFAULT__|${LAN_IF_DEFAULT}|g"     -e "s|__LAN_NET_DEFAULT__|${LAN_NET_DEFAULT}|g"     -e "s|__HOST_IP_DEFAULT__|${HOST_IP_DEFAULT}|g"     -e "s|__HOST_IP_CIDR_REAL__|${HOST_IP_CIDR_REAL}|g"     -e "s|__HOST_GATEWAY_DEFAULT__|${HOST_GATEWAY_DEFAULT}|g"     -e "s|__NAMESERVER_DEFAULT__|${NAMESERVER_DEFAULT}|g"     -e "s|__AUTOINSTALL_HTTP_HOST__|${AUTOINSTALL_HTTP_HOST}|g"     -e "s|__AUTOINSTALL_HTTP_PORT__|${AUTOINSTALL_HTTP_PORT}|g"     -e "s|__MAILSTACK_REPO_CLONE_URL__|${MAILSTACK_REPO_CLONE_URL}|g"     "${in_file}" > "${out_file}"
}

render_template "${SCRIPT_DIR}/install.conf.78.lab.template" "${OUT_DIR}/install.conf.78.lab"
render_template "${SCRIPT_DIR}/install.conf.78.real.template" "${OUT_DIR}/install.conf.78.real"
render_template "${SCRIPT_DIR}/site78_root/install.site.template" "${SITE_ROOT}/install.site"
render_template "${SCRIPT_DIR}/site78_root/root/phase00-firstboot.sh.template" "${SITE_ROOT}/root/phase00-firstboot.sh"

cp "${SCRIPT_DIR}/disklabel-root-swap.template" "${OUT_DIR}/disklabel-root-swap.template"
chmod 755 "${SITE_ROOT}/install.site" "${SITE_ROOT}/root/phase00-firstboot.sh"

(
  cd "${SITE_ROOT}"
  tar -czf "${OUT_DIR}/site78.tgz" .
)

cat > "${OUT_DIR}/ACCOUNT-READINESS.md" <<EOF
# Autonomous Installer Build Output

Profile name: ${PROFILE_NAME}
OpenBSD version: ${OPENBSD_VERSION}
System hostname: ${SYSTEM_HOSTNAME}
DNS domain: ${DNS_DOMAIN}
Operator user: ${OPERATOR_USER}
Operator home: ${OPERATOR_HOME}
LAN interface default: ${LAN_IF_DEFAULT}
LAN network default: ${LAN_NET_DEFAULT}
Host IP default: ${HOST_IP_DEFAULT}

Generated files:
- install.conf.78.lab
- install.conf.78.real
- disklabel-root-swap.template
- site78.tgz

Reminder:
- serve this directory over HTTP during autoinstall
- do not commit your local profile with live secrets
EOF

echo "Rendered installer pack into ${OUT_DIR}"
