#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
READ_SKILL="${REPO_ROOT}/skills/karpathy-wiki-read/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "${READ_SKILL}" ]] || fail "read skill missing"

grep -Fq '6 or more' "${READ_SKILL}" \
  || fail "Step B does not treat a term that hits 6 or more index entries as common"

grep -Fq 'rare term' "${READ_SKILL}" \
  || fail "Step B does not let rare terms select candidates"

grep -Fq 'common term' "${READ_SKILL}" \
  || fail "Step B does not treat high-df terms as common"

grep -Fq 'unless that would leave zero pages' "${READ_SKILL}" \
  || fail "Step B does not skip a common-term AND that would empty the set"

grep -Fq 'tag list' "${READ_SKILL}" \
  || fail "Step B census does not include the index tag list"

grep -Fq 'denylist of tag names' "${READ_SKILL}" \
  || fail "Step B must not special-case tag names"

echo "PASS: read skill uses rare terms to select and common terms only to filter"
