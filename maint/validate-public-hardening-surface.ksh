#!/bin/ksh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"

print -- "Running targeted public hardening validation from ${PROJECT_ROOT}"
"${PROJECT_ROOT}/scripts/phases/phase-15-apply.ksh"
"${PROJECT_ROOT}/scripts/phases/phase-15-verify.ksh"
"${PROJECT_ROOT}/scripts/phases/phase-16-apply.ksh"
"${PROJECT_ROOT}/scripts/phases/phase-16-verify.ksh"
"${PROJECT_ROOT}/scripts/verify/verify-public-repo-readiness.ksh"
print -- "Targeted public hardening validation completed"
