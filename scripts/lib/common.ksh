#!/bin/ksh
set -u

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin"
export PATH

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P 2>/dev/null || pwd -P)"
CONFIG_DIR="${PROJECT_ROOT}/config"
OPERATOR_INPUT_LIB="${PROJECT_ROOT}/scripts/lib/operator-inputs.ksh"
CORE_RUNTIME_RENDER_ROOT_DEFAULT="${PROJECT_ROOT}/.work/runtime/rootfs"
CORE_RUNTIME_EXAMPLE_ROOT="${PROJECT_ROOT}/services/generated/rootfs"

: "${OPENBSD_MAILSTACK_NONINTERACTIVE:=0}"

[ -f "${OPERATOR_INPUT_LIB}" ] && . "${OPERATOR_INPUT_LIB}"

timestamp() { date -u "+%Y-%m-%dT%H:%M:%SZ"; }
log_info() { print -- "[$(timestamp)] INFO  $*"; }
log_warn() { print -- "[$(timestamp)] WARN  $*" >&2; }
log_error() { print -- "[$(timestamp)] ERROR $*" >&2; }
die() { log_error "$*"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }
require_command() { _cmd="$1"; command_exists "${_cmd}" || die "required command not found: ${_cmd}"; }

source_if_readable() {
  _file="$1"
  [ -f "${_file}" ] || return 0
  [ -r "${_file}" ] || die "input file exists but is not readable: ${_file}"
  . "${_file}"
}

load_config_file() { source_if_readable "$1"; }

core_runtime_render_root() {
  print -- "${OPENBSD_MAILSTACK_CORE_RENDER_ROOT:-${CORE_RUNTIME_RENDER_ROOT_DEFAULT}}"
}

core_runtime_example_root() {
  print -- "${CORE_RUNTIME_EXAMPLE_ROOT}"
}

runtime_secret_file_mode() {
  print -- "${OPENBSD_MAILSTACK_RUNTIME_SECRET_FILE_MODE:-${RUNTIME_SECRET_FILE_MODE:-0600}}"
}

core_runtime_secret_relative_paths() {
  cat <<'EOF'
etc/postfix/mysql_virtual_domains_maps.cf
etc/postfix/mysql_virtual_mailbox_maps.cf
etc/postfix/mysql_virtual_alias_maps.cf
etc/postfix/mysql_virtual_alias_domain_maps.cf
etc/postfix/sasl_passwd
etc/dovecot/dovecot-sql.conf.ext
etc/rspamd/local.d/worker-controller.inc
var/www/postfixadmin/config.local.php
var/www/roundcubemail/config/config.inc.php
EOF
}

is_core_runtime_secret_path() {
  _path="$1"
  case "${_path}" in
    */etc/postfix/mysql_virtual_domains_maps.cf|etc/postfix/mysql_virtual_domains_maps.cf) return 0 ;;
    */etc/postfix/mysql_virtual_mailbox_maps.cf|etc/postfix/mysql_virtual_mailbox_maps.cf) return 0 ;;
    */etc/postfix/mysql_virtual_alias_maps.cf|etc/postfix/mysql_virtual_alias_maps.cf) return 0 ;;
    */etc/postfix/mysql_virtual_alias_domain_maps.cf|etc/postfix/mysql_virtual_alias_domain_maps.cf) return 0 ;;
    */etc/postfix/sasl_passwd|etc/postfix/sasl_passwd) return 0 ;;
    */etc/dovecot/dovecot-sql.conf.ext|etc/dovecot/dovecot-sql.conf.ext) return 0 ;;
    */etc/rspamd/local.d/worker-controller.inc|etc/rspamd/local.d/worker-controller.inc) return 0 ;;
    */var/www/postfixadmin/config.local.php|var/www/postfixadmin/config.local.php) return 0 ;;
    */var/www/roundcubemail/config/config.inc.php|var/www/roundcubemail/config/config.inc.php) return 0 ;;
    *) return 1 ;;
  esac
}

apply_runtime_secret_mode() {
  _path="$1"
  [ -f "${_path}" ] || return 0
  _mode="$(runtime_secret_file_mode)"
  require_command chmod
  chmod "${_mode}" "${_path}" || die "failed to set runtime secret file mode ${_mode} on ${_path}"
}

enforce_core_runtime_secret_permissions_in_tree() {
  _root="$1"
  while IFS= read -r _rel || [ -n "${_rel}" ]; do
    [ -n "${_rel}" ] || continue
    _path="${_root%/}/${_rel}"
    [ -f "${_path}" ] || continue
    apply_runtime_secret_mode "${_path}"
  done <<EOF
$(core_runtime_secret_relative_paths)
EOF
}

file_mode_octal() {
  _path="$1"
  [ -e "${_path}" ] || { print -- ""; return 0; }
  if stat -f '%Lp' "${_path}" >/dev/null 2>&1; then
    stat -f '%Lp' "${_path}"
  elif stat -c '%a' "${_path}" >/dev/null 2>&1; then
    stat -c '%a' "${_path}"
  else
    print -- ""
  fi
}

normalize_mode_octal() {
  _mode="$1"
  _normalized="$(print -- "${_mode}" | sed 's/^0*//')"
  [ -n "${_normalized}" ] || _normalized="0"
  print -- "${_normalized}"
}

load_project_config() {
  if command_exists load_project_operator_inputs; then
    load_project_operator_inputs
    return 0
  fi

  load_config_file "${CONFIG_DIR}/system.conf"
  load_config_file "${CONFIG_DIR}/network.conf"
  load_config_file "${CONFIG_DIR}/domains.conf"
  load_config_file "${CONFIG_DIR}/secrets.conf"
}

is_noninteractive() { [ "${OPENBSD_MAILSTACK_NONINTERACTIVE}" = "1" ]; }
trim_whitespace() { print -- "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
normalize_space_list() { print -- "$1" | awk '{$1=$1; print}'; }

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

confirm_yes_no() {
  _var_name="$1"
  _prompt_text="$2"
  _default_value="${3:-yes}"
  prompt_value "${_var_name}" "${_prompt_text}" "${_default_value}"
  eval "_current_value=\${${_var_name}:-}"
  validate_yes_no "${_current_value}" || die "${_var_name} must be yes or no, got: ${_current_value:-<empty>}"
  export "${_var_name}"
}

validate_hostname() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$' || return 1
  print -- "${_value}" | grep -q '\.' || return 1
  return 0
}

validate_domain() { validate_hostname "$1"; }

validate_email() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
}

validate_numeric() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[0-9]+$'
}

validate_yes_no() {
  _value="$1"
  [ "${_value}" = "yes" ] || [ "${_value}" = "no" ]
}

validate_mode_word() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[A-Za-z0-9_-]+$'
}

validate_identifier() {
  _value="$1"
  print -- "${_value}" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$'
}

validate_sql_identifier() { validate_identifier "$1"; }
validate_selector() { _value="$1"; print -- "${_value}" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'; }
validate_transport_name() { _value="$1"; print -- "${_value}" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'; }
validate_interface_name() { _value="$1"; print -- "${_value}" | grep -Eq '^[A-Za-z0-9._-]+$'; }
validate_absolute_path() { _value="$1"; print -- "${_value}" | grep -Eq '^/'; }
validate_dns_text() {
  _value="$1"
  [ -n "${_value}" ] || return 1
  case "${_value}" in
    *'
'*|*'
'*) return 1 ;;
    *) return 0 ;;
  esac
}
validate_password_value() {
  _value="$1"
  [ -n "${_value}" ] || return 1
  case "${_value}" in
    *'
'*|*'
'*) return 1 ;;
    *) return 0 ;;
  esac
}
validate_password_strength_min() { _value="$1"; [ "${#_value}" -ge 16 ]; }
validate_numeric_id() { validate_numeric "$1"; }

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
  '
}

validate_ipv4_cidr() {
  _value="$1"
  _ip="${_value%/*}"
  _cidr="${_value#*/}"
  [ "${_ip}" != "${_value}" ] || return 1
  validate_ipv4 "${_ip}" || return 1
  validate_numeric "${_cidr}" || return 1
  [ "${_cidr}" -ge 0 ] && [ "${_cidr}" -le 32 ]
}

validate_cidr_network() { validate_ipv4_cidr "$1"; }

validate_port() {
  _value="$1"
  validate_numeric "${_value}" || return 1
  [ "${_value}" -ge 1 ] && [ "${_value}" -le 65535 ]
}

validate_numeric_port() { validate_port "$1"; }

validate_port_list() {
  _value="$(normalize_space_list "$1")"
  [ -n "${_value}" ] || return 1
  for _port in ${_value}; do
    validate_port "${_port}" || return 1
  done
  return 0
}

validate_space_separated_domains() {
  _value="$(normalize_space_list "$1")"
  [ -n "${_value}" ] || return 1
  for _domain in ${_value}; do
    validate_domain "${_domain}" || return 1
  done
  return 0
}

validate_space_separated_emails() {
  _value="$(normalize_space_list "$1")"
  [ -n "${_value}" ] || return 1
  for _email in ${_value}; do
    validate_email "${_email}" || return 1
  done
  return 0
}

validate_host_port() {
  _value="$1"
  case "${_value}" in
    *:*)
      _host="${_value%:*}"
      _port="${_value##*:}"
      [ -n "${_host}" ] || return 1
      validate_port "${_port}" || return 1
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_mail_location() {
  _value="$1"
  [ -n "${_value}" ] || return 1
  ! print -- "${_value}" | grep -q '[\r\n]'
}

require_valid_value() {
  _var_name="$1"
  _validator="$2"
  _description="$3"
  eval "_value=\${${_var_name}:-}"
  [ -n "${_value}" ] || die "${_var_name} is required"
  "${_validator}" "${_value}" || die "${_var_name} is not a valid ${_description}: ${_value}"
  export "${_var_name}"
}

require_valid_hostname() { require_valid_value "$1" validate_hostname "hostname"; }
require_valid_domain() { require_valid_value "$1" validate_domain "domain"; }
require_valid_email() { require_valid_value "$1" validate_email "email address"; }
require_valid_ipv4() { require_valid_value "$1" validate_ipv4 "IPv4 address"; }
require_valid_identifier() { require_valid_value "$1" validate_identifier "identifier"; }
require_valid_password_value() { require_valid_value "$1" validate_password_value "password value"; }

ensure_openbsd() {
  _os="$(uname -s 2>/dev/null || true)"
  [ "${_os}" = "OpenBSD" ] || die "this script must run on OpenBSD, detected ${_os:-unknown}"
}

ensure_openbsd_version() {
  _expected="$1"
  _actual="$(uname -r 2>/dev/null || true)"
  [ "${_actual}" = "${_expected}" ] || die "expected OpenBSD ${_expected}, detected ${_actual:-unknown}"
}

detect_mariadb_service_name() {
  command_exists rcctl || return 1
  if rcctl ls all >/dev/null 2>&1; then
    for _svc in mysqld mariadb_server mariadb mysql_server; do
      rcctl ls all 2>/dev/null | grep -qx "${_svc}" && {
        print -- "${_svc}"
        return 0
      }
    done
    _match="$(rcctl ls all 2>/dev/null | grep -E '^(mysqld|mariadb.*|mysql.*)$' | head -n 1)"
    [ -n "${_match}" ] && {
      print -- "${_match}"
      return 0
    }
  fi
  return 1
}

escape_sh_double_quoted_value() {
  print -- "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g' -e 's/`/\\`/g'
}

write_kv_config() {
  _file="$1"
  shift
  require_command mkdir
  mkdir -p "$(dirname -- "${_file}")" || die "unable to create config directory for ${_file}"
  umask 077
  : > "${_file}" || die "unable to write config file ${_file}"
  while [ "$#" -gt 0 ]; do
    _entry="$1"
    shift
    print -- "${_entry}" >> "${_file}" || die "failed writing config entry to ${_file}"
  done
}

write_named_config() {
  _file="$1"
  shift
  [ $(( $# % 2 )) -eq 0 ] || die "write_named_config requires alternating key and value arguments"
  require_command mkdir
  mkdir -p "$(dirname -- "${_file}")" || die "unable to create config directory for ${_file}"
  umask 077
  : > "${_file}" || die "unable to write config file ${_file}"
  while [ "$#" -gt 1 ]; do
    _key="$1"
    _value="$2"
    shift 2
    _escaped_value="$(escape_sh_double_quoted_value "${_value}")"
    print -- "${_key}=\"${_escaped_value}\"" >> "${_file}" || die "failed writing config entry to ${_file}"
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


require_directory() {
  _dir="$1"
  [ -d "${_dir}" ] || die "required directory not found: ${_dir}"
}

ensure_directory() {
  _dir="$1"
  require_command mkdir
  mkdir -p "${_dir}" || die "failed to create directory: ${_dir}"
}

render_template_file() {
  _src="$1"
  _dst="$2"
  shift 2
  [ -f "${_src}" ] || die "template file not found: ${_src}"
  ensure_directory "$(dirname -- "${_dst}")"
  _is_secret=0
  if is_core_runtime_secret_path "${_dst}"; then
    _is_secret=1
    _saved_umask="$(umask)"
    umask 077
  fi
  : > "${_dst}" || die "unable to write rendered file: ${_dst}"
  while IFS= read -r _line || [ -n "${_line}" ]; do
    _rendered="${_line}"
    for _pair in "$@"; do
      _key="${_pair%%=*}"
      _value="${_pair#*=}"
      _rendered="${_rendered//__${_key}__/${_value}}"
    done
    printf '%s\n' "${_rendered}" >> "${_dst}" || die "failed writing ${_dst}"
  done < "${_src}"
  if [ "${_is_secret}" -eq 1 ]; then
    apply_runtime_secret_mode "${_dst}"
    umask "${_saved_umask}"
  fi
}

copy_tree_contents() {
  _src="$1"
  _dst="$2"
  require_directory "${_src}"
  ensure_directory "${_dst}"
  (cd "${_src}" && tar -cf - .) | (cd "${_dst}" && tar -xpf -) || die "failed to copy tree ${_src} to ${_dst}"
}
