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

MODE=""

usage() {
  cat <<'USAGE'
usage: seed-lab-runtime-state.ksh --apply
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      MODE="apply"
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

[ "${MODE}" = "apply" ] || { usage >&2; exit 1; }

require_root() {
  [ "$(id -u)" -eq 0 ] || die "must run as root"
}

load_inputs() {
  load_project_config
  prompt_value "MAIL_HOSTNAME" "mail host" "mail.example.com"
  prompt_value "PRIMARY_DOMAIN" "primary domain" "example.com"
  prompt_value "DOMAINS" "domains" "example.com example.net example.org"
  prompt_value "INITIAL_MAILBOXES" "initial mailboxes" "postmaster@example.com abuse@example.com admin@example.net"
  prompt_value "INITIAL_MAILBOX_PASSWORD" "initial mailbox password" "lab-mail-password-change-me"
  prompt_value "POSTFIX_VMAIL_BASE" "virtual mail base" "/var/vmail"
  prompt_value "POSTFIX_VMAIL_UID" "virtual mail uid" "2000"
  prompt_value "POSTFIX_VMAIL_GID" "virtual mail gid" "2000"
  prompt_value "MYSQL_ROOT_PASSWORD" "mysql root password"
  prompt_value "POSTFIX_DB_NAME" "postfix db name" "postfixadmin"
  prompt_value "POSTFIX_DB_USER" "postfix db user" "postfixadmin"
  prompt_value "POSTFIX_DB_PASSWORD" "postfix db password"
  prompt_value "DOVECOT_DB_NAME" "dovecot db name" "postfixadmin"
  prompt_value "DOVECOT_DB_USER" "dovecot db user" "postfixadmin"
  prompt_value "DOVECOT_DB_PASSWORD" "dovecot db password"
  prompt_value "ROUNDCUBE_DB_NAME" "roundcube db name" "roundcube"
  prompt_value "ROUNDCUBE_DB_USER" "roundcube db user" "roundcube"
  prompt_value "ROUNDCUBE_DB_PASSWORD" "roundcube db password"
  prompt_value "TLS_CERT_PATH_FULLCHAIN" "tls fullchain path" "/etc/ssl/${MAIL_HOSTNAME}.fullchain.pem"
  prompt_value "TLS_CERT_PATH_KEY" "tls key path" "/etc/ssl/private/${MAIL_HOSTNAME}.key"
  prompt_value "DKIM_SELECTOR" "dkim selector" "mail"
}

ensure_vmail_principal() {
  if ! grep -Eq '^_vmail:' /etc/group 2>/dev/null; then
    groupadd -g "${POSTFIX_VMAIL_GID}" _vmail >/dev/null 2>&1 || groupadd _vmail >/dev/null 2>&1 || true
  fi
  if ! grep -Eq '^_vmail:' /etc/passwd 2>/dev/null; then
    useradd -u "${POSTFIX_VMAIL_UID}" -g _vmail -d /var/empty -s /sbin/nologin _vmail >/dev/null 2>&1 || true
  fi
  install -d -m 0750 -o _vmail -g _vmail "${POSTFIX_VMAIL_BASE}"
}

ensure_maildirs() {
  for _mailbox in ${INITIAL_MAILBOXES}; do
    _domain="${_mailbox#*@}"
    _local="${_mailbox%@*}"
    _maildir="${POSTFIX_VMAIL_BASE}/${_domain}/${_local}"
    install -d -m 0750 -o _vmail -g _vmail "${_maildir}" "${_maildir}/cur" "${_maildir}/new" "${_maildir}/tmp"
  done
}

ensure_tls_material() {
  [ -f "${TLS_CERT_PATH_FULLCHAIN}" ] && [ -f "${TLS_CERT_PATH_KEY}" ] && return 0
  install -d -m 0700 "$(dirname -- "${TLS_CERT_PATH_KEY}")"
  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "${TLS_CERT_PATH_KEY}" \
    -out "${TLS_CERT_PATH_FULLCHAIN}" \
    -days 365 \
    -subj "/CN=${MAIL_HOSTNAME}" >/dev/null 2>&1 || die "failed to generate lab TLS material"
  chmod 0600 "${TLS_CERT_PATH_KEY}"
  chmod 0644 "${TLS_CERT_PATH_FULLCHAIN}"
}

ensure_dkim_material() {
  install -d -m 0750 -o _rspamd -g _rspamd /var/rspamd /var/rspamd/dkim || true
  for _domain in ${DOMAINS}; do
    _key="/var/rspamd/dkim/${_domain}.${DKIM_SELECTOR}.key"
    if [ -f "${_key}" ]; then
      continue
    fi
    openssl genrsa -out "${_key}" 2048 >/dev/null 2>&1 || die "failed generating DKIM key for ${_domain}"
    chown _rspamd:_rspamd "${_key}" || true
    chmod 0640 "${_key}"
  done
}

mariadb_service_name() {
  detect_mariadb_service_name || print -- "mysqld"
}

ensure_service_enabled_and_started() {
  _svc="$1"
  if rcctl ls all 2>/dev/null | grep -qx "${_svc}"; then
    rcctl enable "${_svc}" >/dev/null 2>&1 || true
    rcctl start "${_svc}" >/dev/null 2>&1 || rcctl restart "${_svc}" >/dev/null 2>&1 || true
  fi
}

bootstrap_mariadb_if_needed() {
  if [ ! -d /var/mysql/mysql ]; then
    if command_exists mariadb-install-db; then
      mariadb-install-db --user=_mysql --basedir=/usr/local >/dev/null 2>&1 || true
    elif command_exists mysql_install_db; then
      mysql_install_db --user=_mysql --basedir=/usr/local >/dev/null 2>&1 || true
    fi
  fi
}

wait_for_mysql() {
  _i=0
  while [ "${_i}" -lt 30 ]; do
    if mysqladmin ping >/dev/null 2>&1; then
      return 0
    fi
    _i=$(( _i + 1 ))
    sleep 2
  done
  return 1
}

set_root_password_if_needed() {
  if mysql -u root -e 'SELECT 1' >/dev/null 2>&1; then
    mysql -u root <<EOFSQL >/dev/null 2>&1 || true
ALTER USER IF EXISTS 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MYSQL_ROOT_PASSWORD}');
FLUSH PRIVILEGES;
EOFSQL
  fi
}

mysql_root_exec() {
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "$@"
}

ensure_mail_schema() {
  mysql_root_exec <<EOFSQL
CREATE DATABASE IF NOT EXISTS ${POSTFIX_DB_NAME};
CREATE DATABASE IF NOT EXISTS ${ROUNDCUBE_DB_NAME};
CREATE USER IF NOT EXISTS '${POSTFIX_DB_USER}'@'localhost' IDENTIFIED BY '${POSTFIX_DB_PASSWORD}';
CREATE USER IF NOT EXISTS '${ROUNDCUBE_DB_USER}'@'localhost' IDENTIFIED BY '${ROUNDCUBE_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${POSTFIX_DB_NAME}.* TO '${POSTFIX_DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${ROUNDCUBE_DB_NAME}.* TO '${ROUNDCUBE_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
USE ${POSTFIX_DB_NAME};
CREATE TABLE IF NOT EXISTS domain (
  domain varchar(255) NOT NULL,
  description varchar(255) NOT NULL default '',
  aliases int NOT NULL default '0',
  mailboxes int NOT NULL default '0',
  maxquota bigint NOT NULL default '0',
  quota bigint NOT NULL default '0',
  transport varchar(255) NOT NULL default 'virtual',
  backupmx tinyint NOT NULL default '0',
  created datetime NOT NULL,
  modified datetime NOT NULL,
  active tinyint NOT NULL default '1',
  PRIMARY KEY (domain)
);
CREATE TABLE IF NOT EXISTS mailbox (
  username varchar(255) NOT NULL,
  password varchar(255) NOT NULL,
  name varchar(255) NOT NULL default '',
  maildir varchar(255) NOT NULL,
  quota bigint NOT NULL default '0',
  local_part varchar(255) NOT NULL,
  domain varchar(255) NOT NULL,
  created datetime NOT NULL,
  modified datetime NOT NULL,
  active tinyint NOT NULL default '1',
  PRIMARY KEY (username),
  KEY domain (domain)
);
CREATE TABLE IF NOT EXISTS alias (
  address varchar(255) NOT NULL,
  goto text NOT NULL,
  domain varchar(255) NOT NULL,
  created datetime NOT NULL,
  modified datetime NOT NULL,
  active tinyint NOT NULL default '1',
  PRIMARY KEY (address),
  KEY domain (domain)
);
CREATE TABLE IF NOT EXISTS alias_domain (
  alias_domain varchar(255) NOT NULL,
  target_domain varchar(255) NOT NULL,
  created datetime NOT NULL,
  modified datetime NOT NULL,
  active tinyint NOT NULL default '1',
  PRIMARY KEY (alias_domain)
);
EOFSQL
}

seed_mail_rows() {
  _hash="$(doveadm pw -s BLF-CRYPT -p "${INITIAL_MAILBOX_PASSWORD}")"
  for _domain in ${DOMAINS}; do
    mysql_root_exec <<EOFSQL
USE ${POSTFIX_DB_NAME};
INSERT INTO domain (domain, description, aliases, mailboxes, maxquota, quota, transport, backupmx, created, modified, active)
VALUES ('${_domain}', 'lab domain ${_domain}', 10, 10, 0, 0, 'virtual', 0, NOW(), NOW(), 1)
ON DUPLICATE KEY UPDATE modified=NOW(), active=1;
EOFSQL
  done

  for _mailbox in ${INITIAL_MAILBOXES}; do
    _domain="${_mailbox#*@}"
    _local="${_mailbox%@*}"
    _maildir="${_domain}/${_local}/"
    mysql_root_exec <<EOFSQL
USE ${POSTFIX_DB_NAME};
INSERT INTO mailbox (username, password, name, maildir, quota, local_part, domain, created, modified, active)
VALUES ('${_mailbox}', '${_hash}', '${_local}', '${_maildir}', 0, '${_local}', '${_domain}', NOW(), NOW(), 1)
ON DUPLICATE KEY UPDATE password='${_hash}', maildir='${_maildir}', modified=NOW(), active=1;
INSERT INTO alias (address, goto, domain, created, modified, active)
VALUES ('${_mailbox}', '${_mailbox}', '${_domain}', NOW(), NOW(), 1)
ON DUPLICATE KEY UPDATE goto='${_mailbox}', modified=NOW(), active=1;
EOFSQL
  done
}

attempt_roundcube_schema_import() {
  for _candidate in \
    /var/www/roundcubemail/SQL/mysql.initial.sql \
    /usr/local/share/examples/roundcubemail/SQL/mysql.initial.sql \
    /usr/local/share/roundcubemail/SQL/mysql.initial.sql
  do
    if [ -f "${_candidate}" ]; then
      mysql_root_exec "${ROUNDCUBE_DB_NAME}" < "${_candidate}" >/dev/null 2>&1 || true
      return 0
    fi
  done
  return 0
}

restart_core_services() {
  _mariadb="$(mariadb_service_name)"
  ensure_service_enabled_and_started "${_mariadb}"
  ensure_service_enabled_and_started redis
  ensure_service_enabled_and_started rspamd
  ensure_service_enabled_and_started clamd
  ensure_service_enabled_and_started freshclam
  ensure_service_enabled_and_started postfix
  ensure_service_enabled_and_started dovecot
  ensure_service_enabled_and_started nginx
  if rcctl ls all 2>/dev/null | grep -qx php83_fpm; then
    ensure_service_enabled_and_started php83_fpm
  elif rcctl ls all 2>/dev/null | grep -qx php84_fpm; then
    ensure_service_enabled_and_started php84_fpm
  fi
}

main() {
  require_root
  ensure_openbsd
  load_inputs
  ensure_vmail_principal
  ensure_maildirs
  ensure_tls_material
  bootstrap_mariadb_if_needed
  restart_core_services
  wait_for_mysql || die "mysql did not become ready"
  set_root_password_if_needed
  wait_for_mysql || true
  ensure_mail_schema
  seed_mail_rows
  attempt_roundcube_schema_import
  ensure_dkim_material
  restart_core_services
  log_info "lab runtime state seeded successfully"
}

main "$@"
