#!/bin/ksh
set -u

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin"
export PATH

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P 2>/dev/null || pwd -P)"
CONFIG_DIR="${PROJECT_ROOT}/config"

: "${OPENBSD_MAILSTACK_NONINTERACTIVE:=0}"

timestamp() { date -u "+%Y-%m-%dT%H:%M:%SZ"; }
log_info() { print -- "[$(timestamp)] INFO  $*"; }
log_warn() { print -- "[$(timestamp)] WARN  $*" >&2; }
log_error() { print -- "[$(timestamp)] ERROR $*" >&2; }
die() { log_error "$*"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }
require_command() { _cmd="$1"; command_exists "${_cmd}" || die "required command not found: ${_cmd}"; }

load_config_file() { _file="$1"; [ -f "${_file}" ] && . "${_file}"; }
load_project_config() {
  load_config_file "${CONFIG_DIR}/system.conf"
  load_config_file "${CONFIG_DIR}/network.conf"
  load_config_file "${CONFIG_DIR}/domains.conf"
  load_config_file "${CONFIG_DIR}/secrets.conf"
}

is_noninteractive() { [ "${OPENBSD_MAILSTACK_NONINTERACTIVE}" = "1" ]; }
trim_whitespace() { print -- "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }

prompt_value() {
  _var_name="$1"
  _prompt_text="$2"
  _default_value="${3:-}"
  eval "_current_value=\${${_var_name}:-}"
  [ -n "${_current_value}" ] && return 0
  is_noninteractive && die "required setting ${_var_name} is missing and interactive prompting is disabled"
  if [ -n "${_default_value}" ]; then
    printf "%s [%s]: " "${_prompt_text}" "${_default_value}" >&2
  else
    printf "%s: " "${_prompt_text}" >&2
  fi
  IFS= read -r _input_value || die "failed reading input for ${_var_name}"
  _input_value="$(trim_whitespace "${_input_value}")"
  [ -z "${_input_value}" ] && [ -n "${_default_value}" ] && _input_value="${_default_value}"
  [ -n "${_input_value}" ] || die "required setting ${_var_name} was left empty"
  eval "${_var_name}=\${_input_value}"
  export "${_var_name}"
}

validate_hostname() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$' || return 1
  print -- "${_value}" | grep -q '\.' || return 1
  return 0
}
validate_domain() { validate_hostname "$1"; }
validate_email() { _value="$1"; print -- "${_value}" | grep -Eq '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'; }
validate_numeric() { _value="$1"; print -- "${_value}" | grep -Eq '^[0-9]+$'; }
validate_selector() { _value="$1"; print -- "${_value}" | grep -Eq '^[A-Za-z0-9_-]+$'; }
validate_dns_text() { _value="$1"; [ -n "${_value}" ]; }

validate_space_separated_domains() {
  _value="$1"
  [ -n "${_value}" ] || return 1
  for _domain in ${_value}; do
    validate_domain "${_domain}" || return 1
  done
  return 0
}

write_kv_config() {
  _file="$1"
  shift
  umask 077
  : > "${_file}" || die "unable to write config file ${_file}"
  while [ "$#" -gt 0 ]; do
    _entry="$1"
    shift
    print -- "${_entry}" >> "${_file}" || die "failed writing config entry to ${_file}"
  done
}

print_phase_header() {
  _phase_id="$1"
  _phase_name="$2"
  print
  print -- "============================================================"
  print -- "${_phase_id} ${_phase_name}"
  print -- "============================================================"
  print
}
