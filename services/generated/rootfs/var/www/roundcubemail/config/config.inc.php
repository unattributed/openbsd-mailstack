<?php
$config = [];

/**
 * Database: MariaDB via 127.0.0.1.
 * Real credential is loaded from host-local secrets include below.
 */
$config['db_dsnw'] = 'mysql://roundcube:example-secret-value-123456@127.0.0.1/roundcube';

/**
 * IMAP: Dovecot on the configured public mail hostname, implicit TLS on port 993.
 * Roundcube uses ssl:// for IMAPS (993).
 */
$config['imap_host'] = 'ssl://mail.example.com:993';

/**
 * SMTP: Postfix submission on the configured public mail hostname with STARTTLS on port 587.
 * %u and %p expand to the Roundcube login username/password.
 */
$config['smtp_host']      = 'tls://mail.example.com:587';
$config['smtp_port']      = 587;
$config['smtp_user']      = '%u';
$config['smtp_pass']      = '%p';
$config['smtp_auth_type'] = 'LOGIN';
$config['smtp_helo_host'] = 'mail.example.com';

/** Branding. */
$config['product_name'] = 'example.com webmail';
$config['support_url']  = 'mailto:ops@example.com';

/**
 * Session secret placeholder. Real value is host-local.
 */
$config['des_key'] = 'example-roundcube-des-key-123456';

/**
 * Host-local secret overlay.
 * /etc/roundcube/secrets.inc.php should define:
 *   $config['db_dsnw'] = 'mysql://roundcube:...@127.0.0.1/roundcube';
 *   $config['des_key'] = '...';
 * and must not be committed to git.
 */
$roundcube_secrets = '/etc/roundcube/secrets.inc.php';
if (is_readable($roundcube_secrets)) {
    require $roundcube_secrets;
}

/** Locale. */
$config['language'] = 'en_US';

/**
 * Logging.
 */
$config['temp_dir']   = '/var/www/roundcubemail/temp';
$config['log_driver'] = 'file';
$config['log_dir']    = '/var/www/roundcubemail/logs';
$config['syslog_id']  = 'roundcube';

/**
 * Debug.
 */
$config['debug_level']      = 0;
$config['sql_debug']        = false;
$config['imap_debug']       = false;
$config['smtp_debug']       = false;
$config['per_user_logging'] = false;

/**
 * Users log in with full email addresses.
 */
$config['username_domain']     = '';
$config['include_host_config'] = false;

/**
 * SSL options: verify the Dovecot and Postfix certificates.
 * Hostname verification will now succeed when the configured mail hostname
 * resolves to the local service endpoint through public DNS, split DNS,
 * or a host-local resolver override.
 */
$config['imap_conn_options'] = [
    'ssl' => [
        'verify_peer'       => true,
        'verify_peer_name'  => true,
        'allow_self_signed' => false,
    ],
];

$config['smtp_conn_options'] = [
    'ssl' => [
        'verify_peer'       => true,
        'verify_peer_name'  => true,
        'allow_self_signed' => false,
    ],
];

/**
 * Plugins.
 */
$config['plugins'] = [
    'archive',
    'managesieve',
];
