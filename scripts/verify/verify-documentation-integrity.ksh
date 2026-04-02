#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P)"
COMMON_LIB="${PROJECT_ROOT}/scripts/lib/common.ksh"

[ -f "${COMMON_LIB}" ] || {
  print -- "ERROR missing shared library: ${COMMON_LIB}" >&2
  exit 1
}

. "${COMMON_LIB}"

FAIL=0
WARN=0
PASS=0

pass() { print -- "[$(timestamp)] PASS  $*"; PASS=$((PASS + 1)); }
warn() { print -- "[$(timestamp)] WARN  $*"; WARN=$((WARN + 1)); }
fail() { print -- "[$(timestamp)] FAIL  $*"; FAIL=$((FAIL + 1)); }

if command_exists python3; then
  PYTHON_BIN="$(command -v python3)"
elif command_exists python; then
  PYTHON_BIN="$(command -v python)"
else
  die "python interpreter not available for documentation integrity checks"
fi

TMP_RESULT="$(mktemp "${TMPDIR:-/tmp}/openbsd-mailstack-docs.XXXXXX")"
cleanup() {
  rm -f "${TMP_RESULT}"
}
trap cleanup EXIT HUP INT TERM

"${PYTHON_BIN}" - "${PROJECT_ROOT}" >"${TMP_RESULT}" <<'PYEOF'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
md_files = sorted(root.rglob('*.md'))
link_re = re.compile(r'\[[^\]]+\]\(([^)]+)\)')
path_re = re.compile(r'(?<![A-Za-z0-9_./-])(\./[A-Za-z0-9_./<>-]+|README\.md|CONTRIBUTING\.md|SECURITY\.md|CODE_OF_CONDUCT\.md|docs/[A-Za-z0-9_./<>-]+|scripts/[A-Za-z0-9_./<>-]+|maint/[A-Za-z0-9_./<>-]+|services/[A-Za-z0-9_./<>-]+|config/[A-Za-z0-9_./<>-]+)')

allow_missing_suffixes = ('.local', '.local.env')
allow_missing_fragments = (
    'config/local/',
    '.work/',
    '/build/',
    '<profile-name>',
    'build/default',
    '<',
)

def allowed_missing(target: str) -> bool:
    if any(target.endswith(s) for s in allow_missing_suffixes):
        return True
    if any(fragment in target for fragment in allow_missing_fragments):
        return True
    return False

missing_links = []
missing_paths = []

for md in md_files:
    text = md.read_text(encoding='utf-8')

    for match in link_re.finditer(text):
        target = match.group(1).strip()
        if not target or target.startswith(('http://', 'https://', 'mailto:', '#')):
            continue
        target = target.split('#', 1)[0]
        if not target:
            continue
        resolved = (md.parent / target).resolve()
        if not resolved.exists():
            missing_links.append((md.relative_to(root).as_posix(), target))

    for match in path_re.finditer(text):
        target = match.group(1).rstrip('.,:)`')
        repo_rel = target[2:] if target.startswith('./') else target
        if repo_rel.startswith('/'):
            continue
        if allowed_missing(repo_rel):
            continue
        resolved = (root / repo_rel).resolve()
        if resolved.exists():
            continue
        example_resolved = None
        if repo_rel.startswith('config/') and repo_rel.endswith('.conf'):
            example_resolved = (root / f"{repo_rel}.example").resolve()
        if example_resolved is not None and example_resolved.exists():
            continue
        missing_paths.append((md.relative_to(root).as_posix(), target))

for path, target in missing_links:
    print(f'MISSING_LINK\t{path}\t{target}')
for path, target in missing_paths:
    print(f'MISSING_PATH\t{path}\t{target}')
PYEOF

if [ ! -s "${TMP_RESULT}" ]; then
  pass "all markdown links and documented repo paths resolve or are intentionally local/generated"
else
  TAB="$(printf '\t')"
  while IFS="${TAB}" read -r _kind _doc _target; do
    case "${_kind}" in
      MISSING_LINK)
        fail "broken markdown link in ${_doc}: ${_target}"
        ;;
      MISSING_PATH)
        fail "documented repo path in ${_doc} does not exist: ${_target}"
        ;;
      *)
        warn "unexpected documentation checker output: ${_kind} ${_doc} ${_target}"
        ;;
    esac
  done < "${TMP_RESULT}"
fi

print
print -- "Documentation integrity summary"
print -- "  PASS count : ${PASS}"
print -- "  WARN count : ${WARN}"
print -- "  FAIL count : ${FAIL}"
print

[ "${FAIL}" -eq 0 ]
