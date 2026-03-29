#!/bin/ksh
set -u

: "${OPENBSD_MAILSTACK_INPUT_ROOT:=}"
: "${OPENBSD_MAILSTACK_EXTRA_INPUT_FILES:=}"

operator_input_root() {
  if [ -n "${OPENBSD_MAILSTACK_INPUT_ROOT}" ]; then
    print -- "${OPENBSD_MAILSTACK_INPUT_ROOT}"
    return 0
  fi
  print -- "${PROJECT_ROOT}/config/local"
}

load_named_input_files_from_root() {
  _root="$1"
  shift
  [ -n "${_root}" ] || return 0
  for _rel in "$@"; do
    source_if_readable "${_root}/${_rel}"
  done
}

load_extra_operator_input_files() {
  [ -n "${OPENBSD_MAILSTACK_EXTRA_INPUT_FILES}" ] || return 0
  _old_ifs="$IFS"
  IFS=':'
  for _extra_file in ${OPENBSD_MAILSTACK_EXTRA_INPUT_FILES}; do
    [ -n "${_extra_file}" ] || continue
    source_if_readable "${_extra_file}"
  done
  IFS="${_old_ifs}"
}

load_project_operator_inputs() {
  _repo_root="${PROJECT_ROOT}/config"
  _overlay_root="$(operator_input_root)"
  _home_root=""
  _host_root="/root/.config/openbsd-mailstack"

  if [ -n "${HOME:-}" ]; then
    _home_root="${HOME}/.config/openbsd-mailstack"
  fi

  load_named_input_files_from_root "${_repo_root}"         "system.conf"         "network.conf"         "domains.conf"         "secrets.conf"         "dns.conf"         "ddns.conf"         "suricata.conf"         "brevo-webhook.conf"         "sogo.conf"         "sbom.conf"

  load_named_input_files_from_root "${_overlay_root}"         "system.conf"         "network.conf"         "domains.conf"         "secrets.conf"         "dns.conf"         "ddns.conf"         "suricata.conf"         "brevo-webhook.conf"         "sogo.conf"         "sbom.conf"         "providers/vultr.env"         "providers/brevo.env"         "providers/virustotal.env"         "operator.env"

  if [ -n "${_home_root}" ]; then
    load_named_input_files_from_root "${_home_root}"           "system.conf"           "network.conf"           "domains.conf"           "secrets.conf"           "dns.conf"           "ddns.conf"         "suricata.conf"         "brevo-webhook.conf"         "sogo.conf"         "sbom.conf"           "providers/vultr.env"           "providers/brevo.env"           "providers/virustotal.env"           "operator.env"
  fi

  load_named_input_files_from_root "${_host_root}"         "system.conf"         "network.conf"         "domains.conf"         "secrets.conf"         "dns.conf"         "ddns.conf"         "suricata.conf"         "brevo-webhook.conf"         "sogo.conf"         "sbom.conf"         "providers/vultr.env"         "providers/brevo.env"         "providers/virustotal.env"         "operator.env"

  source_if_readable "/root/.config/vultr/api.env"
  source_if_readable "/root/.config/brevo/brevo.env"
  source_if_readable "/root/.config/virustotal/vt.env"

  load_extra_operator_input_files
}

operator_input_search_order() {
  cat <<EOF
1. ${PROJECT_ROOT}/config/*.conf, including suricata.conf, brevo-webhook.conf, sogo.conf, sbom.conf
2. $(operator_input_root)/*.conf
3. $(operator_input_root)/providers/*.env
4. ${HOME:-/root}/.config/openbsd-mailstack/*.conf and providers/*.env
5. /root/.config/openbsd-mailstack/*.conf and providers/*.env
   - includes suricata.conf, brevo-webhook.conf, sogo.conf, sbom.conf
6. Legacy provider paths:
   - /root/.config/vultr/api.env
   - /root/.config/brevo/brevo.env
   - /root/.config/virustotal/vt.env
7. Colon-separated files from OPENBSD_MAILSTACK_EXTRA_INPUT_FILES
EOF
}
