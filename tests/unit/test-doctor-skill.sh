#!/bin/bash
# Verify karpathy-wiki-doctor skill structure and census contract.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SKILL="${REPO_ROOT}/skills/karpathy-wiki-doctor/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "${SKILL}" ]] || fail "skill file missing: ${SKILL}"

head -12 "${SKILL}" | grep -q '^name: karpathy-wiki-doctor' || fail "frontmatter missing name"
head -12 "${SKILL}" | grep -q '^description:' || fail "frontmatter missing description"
head -12 "${SKILL}" | grep -qi 'Detached doctor' || fail "description must say detached doctor"

grep -q 'wiki-complete-doctor.sh' "${SKILL}" || fail "skill missing complete-doctor helper"
grep -q '.wiki-pending/rewrite-jobs/' "${SKILL}" || fail "skill missing rewrite-jobs path"
grep -q 'wiki-schema-patch.py' "${SKILL}" || fail "skill must patch schema.md"
grep -q 'wiki-validate-page.py' "${SKILL}" || fail "skill must name page validation script"
grep -q 'wiki-lint-tags.py' "${SKILL}" || fail "skill must name tag lint script"
grep -qi 'frontmatter' "${SKILL}" || fail "skill missing frontmatter edits"
grep -qi 'related' "${SKILL}" || fail "skill missing related-list edits"

if grep -qi 'rewrite page bodies\|rewrite the body\|rewrite page synthesis' "${SKILL}"; then
  :
else
  grep -q 'Leave page synthesis unchanged' "${SKILL}" \
    || fail "skill must leave page synthesis unchanged"
fi
grep -q 'Do not execute the rewrite' "${SKILL}" \
  || fail "skill must record rewrite jobs without executing them"
if grep -q 'apply historical 200-line' "${SKILL}"; then
  :
else
  grep -q 'Do not apply historical 200-line' "${SKILL}" \
    || fail "skill must not apply historical page-split proposals"
fi
if grep -q 'NO WIKI WRITE IN THE FOREGROUND' "${SKILL}"; then
  fail "iron law duplicated in doctor skill"
fi

echo "PASS: doctor skill structure"
