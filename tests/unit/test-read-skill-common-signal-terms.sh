#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
READ_SKILL="${REPO_ROOT}/skills/karpathy-wiki-read/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "${READ_SKILL}" ]] || fail "read skill missing"

grep -Fq 'more than half' "${READ_SKILL}" \
  || fail "Step B does not drop terms that match more than half the index"

grep -Fq 'keep the original set' "${READ_SKILL}" \
  || fail "Step B does not keep the original set when every term is common"

grep -Fq 'title or one-liner' "${READ_SKILL}" \
  || fail "common-term drop does not walk title or one-liner"

echo "PASS: read skill drops common signal terms and keeps the original set when all are common"
