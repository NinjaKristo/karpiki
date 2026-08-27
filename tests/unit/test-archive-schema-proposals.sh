#!/bin/bash
# Archive helper moves leftover schema-proposals; missing/empty is success.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HELPER="${REPO_ROOT}/scripts/wiki-archive-schema-proposals.py"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "${HELPER}" ]] || fail "wiki-archive-schema-proposals.py missing"

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
wiki="${tmp}/wiki"
mkdir -p "${wiki}"

python3 "${HELPER}" --wiki-root "${wiki}" \
  || fail "missing source must exit 0"

mkdir -p "${wiki}/.wiki-pending/schema-proposals"
python3 "${HELPER}" --wiki-root "${wiki}" \
  || fail "empty source must exit 0"
[[ ! -d "${wiki}/.wiki-pending/schema-proposals" ]] \
  || [[ -z "$(ls -A "${wiki}/.wiki-pending/schema-proposals" 2>/dev/null)" ]] \
  || fail "empty leftover dir should be gone or empty"

mkdir -p "${wiki}/.wiki-pending/schema-proposals"
echo "note" > "${wiki}/.wiki-pending/schema-proposals/2026-08-27-new-tags.md"
python3 "${HELPER}" --wiki-root "${wiki}" \
  || fail "non-empty source must exit 0"
[[ ! -e "${wiki}/.wiki-pending/schema-proposals" ]] \
  || fail "source dir must be gone after archive"
archived="$(find "${wiki}/.wiki-pending/archive" -name '2026-08-27-new-tags.md')"
[[ -n "${archived}" ]] || fail "proposal file must exist under pending archive"
grep -q 'note' "${archived}" || fail "archived file content must be preserved"

python3 "${HELPER}" --wiki-root "${wiki}" \
  || fail "second run must exit 0"

# Doctor start archives leftovers even in test mode (no live model).
wiki2="${tmp}/wiki2"
bash "${REPO_ROOT}/scripts/wiki-init.sh" main "${wiki2}" >/dev/null
mkdir -p "${wiki2}/.wiki-pending/schema-proposals"
echo "left" > "${wiki2}/.wiki-pending/schema-proposals/old.md"
WIKI_DOCTOR_TEST=1 bash "${REPO_ROOT}/scripts/wiki-doctor.sh" "${wiki2}" \
  || fail "wiki doctor test-mode must succeed"
[[ ! -e "${wiki2}/.wiki-pending/schema-proposals" ]] \
  || fail "doctor must archive leftover schema-proposals"
[[ -f "${wiki2}/.wiki-pending/archive/schema-proposals/old.md" ]] \
  || fail "doctor archive must keep the proposal file"

echo "PASS: archive schema-proposals helper"
