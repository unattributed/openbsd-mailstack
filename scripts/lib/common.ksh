#!/bin/ksh
set -u

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin"
export PATH

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P 2>/dev/null || pwd -P)"
CONFIG_DIR="${PROJECT_ROOT}/config"

: "${OPENBSD_MAILSTACK_NONINTERACTIVE:=0}"

timestamp() {
  date -u "+%Y-%m-%dT%H:%M:%SZ"
}

log_info() {
  print -- "[$(timestamp)] INFO  $*"
}

log_warn() {
  print -- "[$(timestamp)] WARN  $*" >&2
}

log_error() {
  print -- "[$(timestamp)] ERROR $*" >&2
}

die() {
  log_error "$*"
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  _cmd="$1"
  command_exists "${_cmd}" || die "required command not found: ${_cmd}"
}

load_config_file() {
  _file="$1"
  if [ -f "${_file}" ]; then
    . "${_file}"
  fi
}

load_project_config() {
  load_config_file "${CONFIG_DIR}/system.conf"
  load_config_file "${CONFIG_DIR}/network.conf"
  load_config_file "${CONFIG_DIR}/domains.conf"
  load_config_file "${CONFIG_DIR}/secrets.conf"
}

is_noninteractive() {
  [ "${OPENBSD_MAILSTACK_NONINTERACTIVE}" = "1" ]
}

trim_whitespace() {
  print -- "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

prompt_value() {
  _var_name="$1"
  _prompt_text="$2"
  _default_value="${3:-}"

  eval "_current_value=\${${_var_name}:-}"
  if [ -n "${_current_value}" ]; then
    return 0
  fi

  if is_noninteractive; then
    die "required setting ${_var_name} is missing and interactive prompting is disabled"
  fi

  if [ -n "${_default_value}" ]; then
    printf "%s [%s]: " "${_prompt_text}" "${_default_value}" >&2
  else
    printf "%s: " "${_prompt_text}" >&2
  fi

  IFS= read -r _input_value || die "failed reading input for ${_var_name}"
  _input_value="$(trim_whitespace "${_input_value}")"

  if [ -z "${_input_value}" ] && [ -n "${_default_value}" ]; then
    _input_value="${_default_value}"
  fi

  [ -n "${_input_value}" ] || die "required setting ${_var_name} was left empty"

  eval "${_var_name}=\${_input_value}"
  export "${_var_name}"
}

validate_domain() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$' || return 1
  print -- "${_value}" | grep -q '\.' || return 1
  return 0
}

validate_email() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
}

validate_sql_identifier() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$'
}

validate_password_strength_min() {
  _value="$1"
  [ "${#_value}" -ge 16 ]
}

validate_transport_name() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[A-Za-z0-9_-]+$'
}

validate_space_separated_domains() {
  _value="$1"
  [ -n "${_value}" ] || return 1
  for _domain in ${_value}; do
    validate_domain "${_domain}" || return 1
  done
  return 0
}

validate_space_separated_emails() {
  _value="$1"
  [ -n "${_value}" ] || return 0
  for _email in ${_value}; do
    validate_email "${_email}" || return 1
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
