#!/usr/local/bin/python3
"""
brevo_webhook.py

Summary:
  Non-blocking Brevo webhook daemon that tracks delivery events and sends
  asynchronous alert mail for critical event types.

Usage:
  BREVO_LOG_PATH=/var/log/brevo-webhook.log \
  BREVO_STATE_PATH=/var/db/brevo/brevo.json \
  BREVO_LISTEN_ADDR=127.0.0.1 \
  BREVO_LISTEN_PORT=9090 \
  /usr/local/bin/python3 brevo_webhook.py
"""

import json
import os
import sys
import time
import signal
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
from typing import Any


LOG_PATH = os.environ.get("BREVO_LOG_PATH", "/var/log/brevo-webhook.log")
STATE_PATH = os.environ.get("BREVO_STATE_PATH", "/var/db/brevo/brevo.json")
ALERT_EMAIL = os.environ.get("BREVO_ALERT_EMAIL", "ops@example.invalid")

LISTEN_ADDR = os.environ.get("BREVO_LISTEN_ADDR", "127.0.0.1")
LISTEN_PORT = int(os.environ.get("BREVO_LISTEN_PORT", "9090"))

ALERT_EVENTS = set(
    os.environ.get(
        "BREVO_ALERT_EVENTS",
        "hard_bounce,blocked,spam,error",
    ).split(",")
)

MAX_RECENT = 50
SENDMAIL_TIMEOUT = 5  # hard cap, never block webhook


def log_line(message: str) -> None:
    """Write an event to file log and syslog, best-effort only."""
    ts = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime())
    line = f"{ts} {message}"

    try:
        with open(LOG_PATH, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except Exception:
        pass

    try:
        subprocess.run(
            ["logger", "-p", "mail.info", "-t", "brevo-webhook", message],
            check=False,
        )
    except Exception:
        pass


def empty_state() -> dict[str, Any]:
    """Return the default persistent state structure."""
    return {
        "updated_epoch": 0,
        "brevo": {
            "totals": {
                "total_events": 0,
                "delivered": 0,
                "bounced": 0,
                "blocked": 0,
                "deferred": 0,
                "spam": 0,
            }
        },
        "recent": [],
    }


def load_state() -> dict[str, Any]:
    """Load persisted webhook state; return defaults on any error."""
    if not os.path.exists(STATE_PATH):
        return empty_state()
    try:
        with open(STATE_PATH, "r", encoding="utf-8") as fh:
            data = json.load(fh)
            if isinstance(data, dict):
                return data
    except Exception as exc:
        log_line(f"state read failed: {exc}")
    return empty_state()


def save_state(state: dict[str, Any]) -> None:
    """Persist state atomically via tmp file + replace."""
    tmp = STATE_PATH + ".tmp"
    try:
        os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(state, fh, indent=2, sort_keys=True)
        os.replace(tmp, STATE_PATH)
    except Exception as exc:
        log_line(f"state write failed: {exc}")


def fork_sendmail(body: str) -> None:
    """Deliver alert mail in a child process to keep webhook responses fast."""
    try:
        pid = os.fork()
        if pid != 0:
            return
    except Exception:
        return

    try:
        proc = subprocess.Popen(
            ["/usr/sbin/sendmail", "-t", "-oi"],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        proc.communicate(body.encode("utf-8"), timeout=SENDMAIL_TIMEOUT)
    except Exception:
        pass

    os._exit(0)


def send_alert_async(event: str, email: str, message_id: str, ts_iso: str, payload: dict[str, Any]) -> None:
    """Queue an alert email for high-signal Brevo events."""
    subject = f"[brevo] {event} for {email or 'unknown'}"
    body = "\n".join(
        [
            f"To: {ALERT_EMAIL}",
            f"Subject: {subject}",
            "From: brevo-webhook@localhost",
            "",
            f"Event: {event}",
            f"Recipient: {email}",
            f"Message ID: {message_id}",
            f"Timestamp: {ts_iso}",
            "",
            json.dumps(payload, indent=2, sort_keys=True),
            "",
        ]
    )
    fork_sendmail(body)


def normalize(item: dict[str, Any]) -> dict[str, Any]:
    """Normalize incoming Brevo payload item into a stable event record."""
    event = (item.get("event") or "unknown").lower()
    email = item.get("email") or ""
    message_id = item.get("message-id") or item.get("messageId") or ""
    ts_epoch = int(item.get("ts_epoch") or time.time())
    ts_iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(ts_epoch))
    return {
        "event": event,
        "email": email,
        "message_id": message_id,
        "ts_epoch": ts_epoch,
        "ts_iso": ts_iso,
    }


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    """Thread-per-request HTTP server for webhook ingestion."""
    daemon_threads = True


class Handler(BaseHTTPRequestHandler):
    """Webhook handler for Brevo POST payloads."""
    server_version = "BrevoWebhook/2.0"

    def log_message(self, *args: Any) -> None:
        """Disable default HTTP request logging noise."""
        return

    def do_POST(self) -> None:
        """Accept Brevo webhook events, update state, and enqueue alerts."""
        if self.path not in ("/brevo/webhook", "/brevo/webhook/"):
            self.send_error(404)
            return

        length = self.headers.get("Content-Length")
        if not length:
            self.send_error(400)
            return

        raw = self.rfile.read(int(length))
        try:
            payload = json.loads(raw.decode("utf-8"))
        except Exception:
            self.send_error(400)
            return

        items = payload if isinstance(payload, list) else [payload]

        state = load_state()
        state["updated_epoch"] = int(time.time())

        for item in items:
            if not isinstance(item, dict):
                continue
            ev = normalize(item)

            totals = state["brevo"]["totals"]
            totals["total_events"] += 1

            mapping = {
                "delivered": "delivered",
                "sent": "delivered",
                "soft_bounce": "bounced",
                "hard_bounce": "bounced",
                "bounced": "bounced",
                "blocked": "blocked",
                "deferred": "deferred",
                "spam": "spam",
                "complaint": "spam",
            }

            key = mapping.get(ev["event"])
            if key:
                totals[key] += 1

            state["recent"].insert(
                0,
                {
                    "event": ev["event"],
                    "email": ev["email"],
                    "ts_epoch": ev["ts_epoch"],
                    "ts_iso": ev["ts_iso"],
                    "message_id": ev["message_id"],
                },
            )

            if len(state["recent"]) > MAX_RECENT:
                state["recent"] = state["recent"][:MAX_RECENT]

            if ev["event"] in ALERT_EVENTS:
                send_alert_async(
                    ev["event"],
                    ev["email"],
                    ev["message_id"],
                    ev["ts_iso"],
                    item,
                )

        save_state(state)

        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"ok\n")


def handle_term(signum: int, frame: Any) -> None:
    """Exit cleanly on SIGTERM/SIGINT."""
    raise SystemExit(0)


def main() -> None:
    """Boot the webhook listener and serve indefinitely."""
    signal.signal(signal.SIGTERM, handle_term)
    signal.signal(signal.SIGINT, handle_term)

    log_line(f"brevo webhook listening on {LISTEN_ADDR}:{LISTEN_PORT}")
    server = ThreadedHTTPServer((LISTEN_ADDR, LISTEN_PORT), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
