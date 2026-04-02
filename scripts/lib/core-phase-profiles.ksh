#!/bin/ksh
set -u

core_phase_profile_name() {
  case "$1" in
    02) print -- "mariadb baseline" ;;
    03) print -- "postfixadmin and sql wiring" ;;
    04) print -- "postfix core and sql integration" ;;
    05) print -- "dovecot auth and mailbox delivery" ;;
    06) print -- "tls and certificate automation" ;;
    07) print -- "filtering and anti-abuse" ;;
    08) print -- "webmail and administrative access" ;;
    *) die "unsupported core phase profile: $1" ;;
  esac
}

core_phase_profile_template_paths() {
  case "$1" in
    02)
      cat <<'EOF'
services/mariadb/etc/my.cnf.template
scripts/install/render-core-runtime-configs.ksh
scripts/install/install-core-runtime-configs.ksh
EOF
      ;;
    03)
      cat <<'EOF'
services/postfixadmin/var/www/postfixadmin/config.local.php.template
services/postfix/etc/postfix/mysql_virtual_domains_maps.cf.template
services/postfix/etc/postfix/mysql_virtual_mailbox_maps.cf.template
services/postfix/etc/postfix/mysql_virtual_alias_maps.cf.template
services/postfix/etc/postfix/mysql_virtual_alias_domain_maps.cf.template
scripts/install/render-core-runtime-configs.ksh
scripts/install/install-core-runtime-configs.ksh
EOF
      ;;
    04)
      cat <<'EOF'
services/postfix/etc/postfix/main.cf.template
services/postfix/etc/postfix/master.cf.template
services/postfix/etc/postfix/mysql_virtual_domains_maps.cf.template
services/postfix/etc/postfix/mysql_virtual_mailbox_maps.cf.template
services/postfix/etc/postfix/mysql_virtual_alias_maps.cf.template
services/postfix/etc/postfix/mysql_virtual_alias_domain_maps.cf.template
services/postfix/etc/postfix/postscreen_access.cidr.template
services/postfix/etc/postfix/tls_policy.template
services/postfix/etc/postfix/sasl_passwd.template
scripts/install/render-core-runtime-configs.ksh
scripts/install/install-core-runtime-configs.ksh
EOF
      ;;
    05)
      cat <<'EOF'
services/dovecot/etc/dovecot/dovecot.conf.template
services/dovecot/etc/dovecot/local.conf.template
services/dovecot/etc/dovecot/dovecot-sql.conf.ext.template
services/dovecot/etc/dovecot/conf.d/99-rspamd-warning-labels.conf
services/dovecot/etc/dovecot/sieve-before/10-rspamd-quarantine.sieve
scripts/install/render-core-runtime-configs.ksh
scripts/install/install-core-runtime-configs.ksh
EOF
      ;;
    06)
      cat <<'EOF'
services/nginx/etc/nginx/templates/ssl.tmpl.template
services/nginx/etc/nginx/sites-available/main-ssl.conf.template
services/postfix/etc/postfix/main.cf.template
services/dovecot/etc/dovecot/local.conf.template
scripts/install/render-core-runtime-configs.ksh
scripts/install/install-core-runtime-configs.ksh
EOF
      ;;
    07)
      cat <<'EOF'
services/rspamd/etc/rspamd/local.d/worker-controller.inc.template
services/rspamd/etc/rspamd/local.d/worker-proxy.inc.template
services/rspamd/etc/rspamd/local.d/redis.conf.template
services/rspamd/etc/rspamd/local.d/antivirus.conf.template
services/rspamd/etc/rspamd/local.d/dkim_signing.conf.template
services/redis/etc/redis.conf.template
services/clamd/etc/clamd.conf.template
services/freshclam/etc/freshclam.conf.template
scripts/install/render-core-runtime-configs.ksh
scripts/install/install-core-runtime-configs.ksh
EOF
      ;;
    08)
      cat <<'EOF'
services/nginx/etc/nginx/sites-available/main.conf.template
services/nginx/etc/nginx/sites-available/main-ssl.conf.template
services/nginx/etc/nginx/control-plane.allow.template
services/nginx/etc/nginx/templates/postfixadmin.tmpl
services/nginx/etc/nginx/templates/roundcube.tmpl
services/nginx/etc/nginx/templates/rspamd.tmpl.template
services/postfixadmin/var/www/postfixadmin/config.local.php.template
services/roundcube/var/www/roundcubemail/config/config.inc.php.template
scripts/install/render-core-runtime-configs.ksh
scripts/install/install-core-runtime-configs.ksh
EOF
      ;;
  esac
}

core_phase_profile_rendered_paths() {
  case "$1" in
    02)
      cat <<'EOF'
etc/my.cnf
EOF
      ;;
    03)
      cat <<'EOF'
etc/postfix/mysql_virtual_domains_maps.cf
etc/postfix/mysql_virtual_mailbox_maps.cf
etc/postfix/mysql_virtual_alias_maps.cf
etc/postfix/mysql_virtual_alias_domain_maps.cf
var/www/postfixadmin/config.local.php
EOF
      ;;
    04)
      cat <<'EOF'
etc/postfix/main.cf
etc/postfix/master.cf
etc/postfix/mysql_virtual_domains_maps.cf
etc/postfix/mysql_virtual_mailbox_maps.cf
etc/postfix/mysql_virtual_alias_maps.cf
etc/postfix/mysql_virtual_alias_domain_maps.cf
etc/postfix/postscreen_access.cidr
etc/postfix/tls_policy
etc/postfix/sasl_passwd
EOF
      ;;
    05)
      cat <<'EOF'
etc/dovecot/dovecot.conf
etc/dovecot/local.conf
etc/dovecot/dovecot-sql.conf.ext
etc/dovecot/conf.d/99-rspamd-warning-labels.conf
etc/dovecot/sieve-before/10-rspamd-quarantine.sieve
EOF
      ;;
    06)
      cat <<'EOF'
etc/nginx/templates/ssl.tmpl
etc/nginx/sites-available/main-ssl.conf
etc/postfix/main.cf
etc/dovecot/local.conf
EOF
      ;;
    07)
      cat <<'EOF'
etc/rspamd/local.d/worker-controller.inc
etc/rspamd/local.d/worker-proxy.inc
etc/rspamd/local.d/redis.conf
etc/rspamd/local.d/antivirus.conf
etc/rspamd/local.d/dkim_signing.conf
etc/redis.conf
etc/clamd.conf
etc/freshclam.conf
EOF
      ;;
    08)
      cat <<'EOF'
etc/nginx/sites-available/main.conf
etc/nginx/sites-available/main-ssl.conf
etc/nginx/control-plane.allow
etc/nginx/templates/postfixadmin.tmpl
etc/nginx/templates/roundcube.tmpl
etc/nginx/templates/rspamd.tmpl
var/www/postfixadmin/config.local.php
var/www/roundcubemail/config/config.inc.php
EOF
      ;;
  esac
}

core_phase_profile_summary_path() {
  _phase="$1"
  print -- "$(core_runtime_render_root)/phase-${_phase}-summary.txt"
}

write_core_phase_profile_summary() {
  _phase="$1"
  _name="$(core_phase_profile_name "${_phase}")"
  _summary_path="$(core_phase_profile_summary_path "${_phase}")"
  ensure_directory "$(dirname -- "${_summary_path}")"
  {
    print -- "Phase ${_phase} targeted summary"
    print -- "phase_name=${_name}"
    print -- "render_root=$(core_runtime_render_root)"
    print -- "example_root=$(core_runtime_example_root)"
    print -- ""
    print -- "required_templates:"
    while IFS= read -r _rel || [ -n "${_rel}" ]; do
      [ -n "${_rel}" ] || continue
      print -- "- ${_rel}"
    done <<EOF
$(core_phase_profile_template_paths "${_phase}")
EOF
    print -- ""
    print -- "required_rendered_files:"
    while IFS= read -r _rel || [ -n "${_rel}" ]; do
      [ -n "${_rel}" ] || continue
      print -- "- ${_rel}"
    done <<EOF
$(core_phase_profile_rendered_paths "${_phase}")
EOF
  } > "${_summary_path}" || die "failed writing phase summary ${_summary_path}"
  log_info "wrote targeted phase summary for ${_phase} to ${_summary_path}"
}

verify_core_phase_profile() {
  _phase="$1"
  _name="$(core_phase_profile_name "${_phase}")"
  _root="$(core_runtime_render_root)"
  _summary_path="$(core_phase_profile_summary_path "${_phase}")"
  _fail=0
  pass() { print -- "[$(timestamp)] PASS  $*"; }
  fail() { print -- "[$(timestamp)] FAIL  $*"; _fail=$(( _fail + 1 )); }

  [ -d "${_root}" ] && pass "live rendered rootfs exists for phase ${_phase}: ${_root}" || fail "live rendered rootfs missing for phase ${_phase}: ${_root}"
  [ -f "${_summary_path}" ] && pass "targeted phase summary present: ${_summary_path}" || fail "targeted phase summary missing: ${_summary_path}"

  while IFS= read -r _rel || [ -n "${_rel}" ]; do
    [ -n "${_rel}" ] || continue
    _path="${PROJECT_ROOT}/${_rel}"
    [ -f "${_path}" ] && pass "phase ${_phase} template present: ${_rel}" || fail "phase ${_phase} template missing: ${_rel}"
  done <<EOF
$(core_phase_profile_template_paths "${_phase}")
EOF

  while IFS= read -r _rel || [ -n "${_rel}" ]; do
    [ -n "${_rel}" ] || continue
    _path="${_root%/}/${_rel}"
    if [ -f "${_path}" ]; then
      pass "phase ${_phase} rendered file present: ${_rel}"
      if grep -Eq '__[A-Z0-9_]+__' "${_path}"; then
        fail "phase ${_phase} rendered file still contains unresolved placeholders: ${_rel}"
      else
        pass "phase ${_phase} rendered file has no unresolved placeholders: ${_rel}"
      fi
      if is_core_runtime_secret_path "${_rel}"; then
        _expected_mode="$(normalize_mode_octal "$(runtime_secret_file_mode)")"
        _actual_mode="$(normalize_mode_octal "$(file_mode_octal "${_path}")")"
        if [ -n "${_actual_mode}" ] && [ "${_actual_mode}" = "${_expected_mode}" ]; then
          pass "phase ${_phase} secret-bearing file mode ok (${_actual_mode}): ${_rel}"
        else
          fail "phase ${_phase} secret-bearing file mode mismatch, expected ${_expected_mode}, got ${_actual_mode:-unknown}: ${_rel}"
        fi
      fi
    else
      fail "phase ${_phase} rendered file missing: ${_rel}"
    fi
  done <<EOF
$(core_phase_profile_rendered_paths "${_phase}")
EOF

  [ "${_fail}" -eq 0 ] || return 1
  log_info "targeted phase ${_phase} verification completed successfully for ${_name}"
}
