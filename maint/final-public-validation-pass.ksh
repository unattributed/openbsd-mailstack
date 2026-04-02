#!/bin/ksh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
NEW_ENTRYPOINT="${PROJECT_ROOT}/maint/validate-public-hardening-surface.ksh"

print -- "NOTICE: maint/final-public-validation-pass.ksh is a compatibility wrapper."
print -- "NOTICE: use maint/validate-public-hardening-surface.ksh for the current targeted validation scope."
exec "${NEW_ENTRYPOINT}" "$@"
