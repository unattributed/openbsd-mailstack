#!/bin/ksh
set -e
set -o pipefail
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin"
export PATH

if ! command -v pfctl >/dev/null 2>&1; then
  print -- "pfctl not found" >&2
  exit 1
fi

print -- "PF status"
pfctl -si || true
print
print -- "PF rules"
pfctl -sr || true
print
print -- "PF tables"
pfctl -s Tables 2>/dev/null || true
