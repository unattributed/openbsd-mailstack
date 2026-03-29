#!/usr/bin/env python3
import json
import os
import sys

domains = os.environ.get("DDNS_DOMAINS", "example.com example.net").split()
labels = os.environ.get("DDNS_HOST_LABELS", "mail").split()
target_ipv4 = os.environ.get("DDNS_TARGET_IPV4", "203.0.113.10")
ttl = os.environ.get("DDNS_TTL", "300")
plan = []
for domain in domains:
    for label in labels:
        name = domain if label in ("@", "") else f"{label}.{domain}"
        plan.append({"type": "A", "name": name, "content": target_ipv4, "ttl": ttl})
json.dump({"mode": "preview", "records": plan}, sys.stdout, indent=2)
sys.stdout.write("\n")
