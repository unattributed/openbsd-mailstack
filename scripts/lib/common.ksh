#!/bin/ksh
#
# scripts/lib/common.ksh
#
# Shared helpers for openbsd-mailstack public phase scripts.
#

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

ensure_openbsd() {
  _os="$(uname -s 2>/dev/null || true)"
  [ "${_os}" = "OpenBSD" ] || die "this project supports OpenBSD only, detected: ${_os:-unknown}"
}

ensure_openbsd_version() {
  _required="$1"
  _current="$(uname -r 2>/dev/null || true)"
  [ "${_current}" = "${_required}" ] || die "supported OpenBSD version is ${_required}, detected ${_current:-unknown}"
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

confirm_yes_no() {
  _var_name="$1"
  _prompt_text="$2"
  _default_value="${3:-yes}"

  eval "_current_value=\${${_var_name}:-}"
  if [ -n "${_current_value}" ]; then
    return 0
  fi

  if is_noninteractive; then
    eval "${_var_name}=\${_default_value}"
    export "${_var_name}"
    return 0
  fi

  case "${_default_value}" in
    yes) printf "%s [Y/n]: " "${_prompt_text}" >&2 ;;
    no)  printf "%s [y/N]: " "${_prompt_text}" >&2 ;;
    *)   printf "%s [yes/no]: " "${_prompt_text}" >&2 ;;
  esac

  IFS= read -r _input_value || die "failed reading input for ${_var_name}"
  _input_value="$(print -- "${_input_value}" | tr '[:upper:]' '[:lower:]')"
  _input_value="$(trim_whitespace "${_input_value}")"

  if [ -z "${_input_value}" ]; then
    _input_value="${_default_value}"
  fi

  case "${_input_value}" in
    y|yes|true|1) eval "${_var_name}=yes" ;;
    n|no|false|0) eval "${_var_name}=no" ;;
    *) die "invalid boolean value for ${_var_name}: ${_input_value}" ;;
  esac

  export "${_var_name}"
}

validate_hostname() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$' || return 1
  print -- "${_value}" | grep -q '\.' || return 1
  return 0
}

validate_domain() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$' || return 1
  print -- "${_value}" | grep -q '\.' || return 1
  return 0
}

validate_ipv4() {
  _value="$1"
  print -- "${_value}" | awk -F. '
    NF != 4 { exit 1 }
    {
      for (i = 1; i <= 4; i++) {
        if ($i !~ /^[0-9]+$/) exit 1
        if ($i < 0 || $i > 255) exit 1
      }
    }
    END { exit 0 }
  '
}

validate_email() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
}

require_valid_hostname() {
  _var_name="$1"
  eval "_value=\${${_var_name}:-}"
  [ -n "${_value}" ] || die "required hostname setting ${_var_name} is missing"
  validate_hostname "${_value}" || die "invalid hostname for ${_var_name}: ${_value}"
}

require_valid_domain() {
  _var_name="$1"
  eval "_value=\${${_var_name}:-}"
  [ -n "${_value}" ] || die "required domain setting ${_var_name} is missing"
  validate_domain "${_value}" || die "invalid domain for ${_var_name}: ${_value}"
}

require_valid_ipv4() {
  _var_name="$1"
  eval "_value=\${${_var_name}:-}"
  [ -n "${_value}" ] || die "required IPv4 setting ${_var_name} is missing"
  validate_ipv4 "${_value}" || die "invalid IPv4 address for ${_var_name}: ${_value}"
}

require_valid_email() {
  _var_name="$1"
  eval "_value=\${${_var_name}:-}"
  [ -n "${_value}" ] || die "required email setting ${_var_name} is missing"
  validate_email "${_value}" || die "invalid email address for ${_var_name}: ${_value}"
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
