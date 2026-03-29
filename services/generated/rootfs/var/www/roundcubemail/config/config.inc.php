<?php
/* Local configuration for Roundcube Webmail */

$config = array();
$config['default_host'] = 'ssl://mail.example.com:993';
$config['smtp_server'] = 'tls://mail.example.com:587';
$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';
$config['smtp_auth_type'] = 'LOGIN';
$config['product_name'] = 'OpenBSD Mailstack Webmail';
$config['support_url'] = '';
$config['plugins'] = array();
$config['skin'] = 'elastic';
$config['des_key'] = '__set_locally__';
$config['smtp_helo_host'] = 'mail.example.com';
