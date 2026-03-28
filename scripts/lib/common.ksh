#!/bin/ksh
set -u
timestamp() { date -u "+%Y-%m-%dT%H:%M:%SZ"; }
log_info() { print -- "[$(timestamp)] INFO $*"; }
die() { print -- "ERROR $*" >&2; exit 1; }
