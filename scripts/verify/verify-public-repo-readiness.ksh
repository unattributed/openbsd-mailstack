#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"

FAIL=0
pass() { print -- "PASS $*"; }
fail() { print -- "FAIL $*"; FAIL=$((FAIL + 1)); }
check_file() {
  _path="$1"
  if [ -e "${PROJECT_ROOT}/${_path}" ]; then
    pass "found ${_path}"
  else
    fail "missing ${_path}"
  fi
}

for _path in \
  README.md \
  docs/project-status.md \
  docs/public-private-boundary.md \
  docs/phases/phase-crosswalk.md \
  docs/install/README.md \
  docs/install/06-qemu-lab-and-vm-testing.md \
  docs/install/07-openbsd-autonomous-installer.md \
  docs/install/09-install-order-and-phase-sequence.md \
  docs/install/10-qemu-first-validation-path.md \
  docs/install/11-first-production-deployment-sequence.md \
  docs/install/12-post-install-checks.md \
  docs/install/13-dr-site-provisioning.md \
  docs/install/14-backup-and-restore-drill-sequence.md \
  docs/install/15-dr-host-bootstrap.md \
  docs/install/16-monitoring-diagnostics-and-reporting.md \
  docs/install/17-maintenance-upgrades-regression-and-rollback.md \
  docs/install/18-advanced-optional-integrations-and-gap-closures.md \
  docs/install/19-public-repo-readiness-check.md \
  maint/qemu/README.md \
  maint/openbsd-autonomous-installer/README.md
 do
  check_file "${_path}"
 done

for _phase in 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17
 do
  if ls "${PROJECT_ROOT}/docs/phases/phase-${_phase}-"*.md >/dev/null 2>&1; then
    pass "phase ${_phase} doc present"
  else
    fail "phase ${_phase} doc missing"
  fi
  check_file "scripts/phases/phase-${_phase}-apply.ksh"
  check_file "scripts/phases/phase-${_phase}-verify.ksh"
 done

_cache_count="$(find "${PROJECT_ROOT}" \( -name '__pycache__' -o -name '*.pyc' \) | wc -l | tr -d ' ')"
if [ "${_cache_count}" = "0" ]; then
  pass "no accidental Python cache artifacts are tracked"
else
  fail "found ${_cache_count} accidental Python cache artifacts"
fi



_private_hostname="mail.blackbagsecurity.com"
_private_ref_count="$(grep -RIn --exclude-dir='.git' --exclude='design-authority-check.ksh' --exclude='verify-public-repo-readiness.ksh' --exclude='20-public-only-validation-pass.md' -- "${_private_hostname}" "${PROJECT_ROOT}" | wc -l | tr -d ' ')"
if [ "${_private_ref_count}" = "0" ]; then
  pass "no live private hostnames remain in tracked public content"
else
  fail "found ${_private_ref_count} live private hostname reference(s) in tracked public content"
fi

_bad_prefix_count="$(grep -RIl '^-[r-] -- ' "${PROJECT_ROOT}/services/generated/rootfs" 2>/dev/null | wc -l | tr -d ' ')"
if [ "${_bad_prefix_count}" = "0" ]; then
  pass "staged generated rootfs files do not carry accidental shell print prefixes"
else
  fail "found ${_bad_prefix_count} staged generated rootfs file(s) with accidental shell print prefixes"
fi

if command -v python3 >/dev/null 2>&1; then
  if PROJECT_ROOT="${PROJECT_ROOT}" python3 - <<'PY'
import os
import re
import sys
from pathlib import Path
root = Path(os.environ['PROJECT_ROOT'])
pat = re.compile(r'\[[^\]]+\]\(([^)]+)\)')
missing = []
for path in root.rglob('*.md'):
    text = path.read_text(encoding='utf-8')
    for link in pat.findall(text):
        if '://' in link or link.startswith('mailto:') or link.startswith('#'):
            continue
        target_ref = link.split('#', 1)[0]
        if not target_ref:
            continue
        target = (path.parent / target_ref).resolve()
        if not target.exists():
            missing.append(f"{path.relative_to(root)} -> {link}")
if missing:
    for item in missing[:50]:
        print(item)
    sys.exit(1)
PY
  then
    pass "markdown links resolve"
  else
    fail "markdown link audit failed"
  fi
else
  fail "python3 is required for markdown link audit"
fi

[ "${FAIL}" -eq 0 ]
