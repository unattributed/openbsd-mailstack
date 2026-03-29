<?php
$CONF['configured'] = true;
$CONF['database_type'] = 'mysqli';
$CONF['database_host'] = '127.0.0.1';
$CONF['database_port'] = '3306';
$CONF['database_user'] = 'postfixadmin';
$CONF['database_password'] = 'example-secret-value-123456';
$CONF['database_name'] = 'postfixadmin';
$CONF['default_language'] = 'en';
$CONF['show_footer_text'] = 'NO';
$CONF['show_footer_text_admin'] = 'NO';
$CONF['quota'] = 'YES';
$CONF['domain_quota'] = 'YES';
$CONF['used_quotas'] = 'YES';
$CONF['new_quota_table'] = 'YES';
$CONF['quota_multiplier'] = '1024000';
$CONF['aliases'] = '0';
$CONF['mailboxes'] = '0';
$CONF['maxquota'] = '0';
$CONF['domain_quota_default'] = '0';
$CONF['setup_password'] = 'example-controller-hash-123456';
$CONF['default_aliases'] = array(
    'abuse'      => 'abuse@example.com',
    'hostmaster' => 'hostmaster@example.com',
    'postmaster' => 'postmaster@example.com',
    'webmaster'  => 'webmaster@example.com',
);
$CONF['admin_email'] = 'ops@example.com';
$CONF['postfix_admin_url'] = 'https://mail.example.com/postfixadmin';
$postfixadmin_secrets = '/etc/postfixadmin/secrets.php';
if (is_readable($postfixadmin_secrets)) {
    require $postfixadmin_secrets;
}
