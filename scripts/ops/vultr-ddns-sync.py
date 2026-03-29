#!/usr/bin/env python3
import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

def split_words(value: str) -> list[str]:
    return [item for item in value.split() if item]

def build_plan() -> list[dict]:
    domains = split_words(os.environ.get("DDNS_DOMAINS", ""))
    labels = split_words(os.environ.get("DDNS_HOST_LABELS", "mail"))
    target_ipv4 = os.environ.get("DDNS_TARGET_IPV4", "")
    ttl = int(os.environ.get("DDNS_TTL", "300"))
    plan = []
    for domain in domains:
        for label in labels:
            record_name = domain if label in {"@", ""} else f"{label}.{domain}"
            plan.append({
                "domain": domain,
                "record_type": "A",
                "record_name": record_name,
                "content": target_ipv4,
                "ttl": ttl,
            })
    return plan

def vultr_request(method: str, path: str, api_key: str, payload: dict | None = None) -> dict:
    api_url = os.environ.get("DDNS_API_URL", "https://api.vultr.com/v2").rstrip("/")
    request = urllib.request.Request(
        api_url + path,
        data=None if payload is None else json.dumps(payload).encode("utf-8"),
        method=method,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read().decode("utf-8")
        return json.loads(body) if body else {}

def apply_plan(plan: list[dict], api_key: str) -> None:
    for record in plan:
        domain = record["domain"]
        existing = vultr_request("GET", f"/domains/{urllib.parse.quote(domain)}/records", api_key)
        match = None
        for item in existing.get("records", []):
            fqdn = domain if item.get("name") in ("", "@") else f"{item.get('name')}.{domain}"
            if item.get("type") == "A" and fqdn == record["record_name"]:
                match = item
                break
        payload = {
            "type": "A",
            "name": "@" if record["record_name"] == domain else record["record_name"].removesuffix("." + domain),
            "data": record["content"],
            "ttl": record["ttl"],
        }
        if match is None:
            result = vultr_request("POST", f"/domains/{urllib.parse.quote(domain)}/records", api_key, payload)
            print(json.dumps({"action": "create", "domain": domain, "result": result}, indent=2))
        else:
            result = vultr_request(
                "PATCH",
                f"/domains/{urllib.parse.quote(domain)}/records/{match['id']}",
                api_key,
                payload,
            )
            print(json.dumps({"action": "update", "domain": domain, "record_id": match['id'], "result": result}, indent=2))

def main() -> int:
    parser = argparse.ArgumentParser(description="Preview or apply Vultr DDNS updates for openbsd-mailstack")
    parser.add_argument("--apply", action="store_true", help="perform live Vultr API changes")
    parser.add_argument("--dry-run", action="store_true", help="print the planned changes and exit")
    args = parser.parse_args()

    plan = build_plan()
    if not plan:
        print("No DDNS records are defined. Set DDNS_DOMAINS and DDNS_HOST_LABELS.", file=sys.stderr)
        return 1

    if args.apply:
        api_key = os.environ.get("VULTR_API_KEY", "")
        if not api_key:
            print("VULTR_API_KEY is required for --apply", file=sys.stderr)
            return 1
        try:
            apply_plan(plan, api_key)
            return 0
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
            print(f"Vultr API request failed: {exc}", file=sys.stderr)
            return 1
    print(json.dumps({"mode": "dry-run", "records": plan}, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
