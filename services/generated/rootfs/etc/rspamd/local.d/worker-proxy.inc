# PHASE-06C: Rspamd proxy worker for Postfix milter integration
# Authoritative pattern based on Rspamd worker docs:
#   worker "rspamd_proxy" { bind_socket = "localhost:11332"; upstream "local" { default = yes; hosts = "127.0.0.1:11333"; } }
# This file is included as worker-proxy.inc, the worker wrapper is implicit.

# Enable milter mode so Postfix can talk to Rspamd via smtpd_milters
milter = yes;

# Conservative timeout for SMTP sessions through the milter
timeout = 120s;

# Listen for Postfix milter connections on localhost:11332
bind_socket = "127.0.0.1:11332";

# Forward scans to the normal worker on 127.0.0.1:11333
upstream "local" {
  default = yes;
  self_scan = yes;  # small single host setup, proxy does the scan directly
  hosts = "127.0.0.1:11333";
}
