#!/bin/bash
# wiki-schema-patch.py updates Objects, tags, and Categories from indexes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT="${REPO_ROOT}/scripts/wiki-init.sh"
BUILD="${REPO_ROOT}/scripts/wiki-build-index.py"
PATCH="${REPO_ROOT}/scripts/wiki-schema-patch.py"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "${PATCH}" ]] || fail "wiki-schema-patch.py missing"

setup() {
  TESTDIR="$(mktemp -d)"
  bash "${INIT}" main "${TESTDIR}/wiki" >/dev/null
}

teardown() { rm -rf "${TESTDIR}"; }

write_page() {
  local path="$1" title="$2" tags="$3"
  cat > "${path}" <<EOF
---
title: "${title}"
type: concepts
tags: ${tags}
sources: []
summary: "${title} summary"
created: "2026-04-26T12:00:00Z"
updated: "2026-04-26T12:00:00Z"
quality:
  accuracy: 4
  completeness: 4
  signal: 4
  interlinking: 4
  overall: 4.00
  rated_at: "2026-04-26T12:00:00Z"
  rated_by: ingester
---
body
EOF
}

test_six_homepage_pages_add_object_and_tags() {
  setup
  local i
  for i in 1 2 3 4 5 6; do
    write_page "${TESTDIR}/wiki/concepts/home-${i}.md" \
      "Homepage layout ${i}" "[homepage, cro]"
  done
  python3 "${BUILD}" --wiki-root "${TESTDIR}/wiki" --rebuild-all
  python3 "${PATCH}" --wiki-root "${TESTDIR}/wiki"
  objects="$(awk '/^## Objects/{f=1;next} /^## /{f=0} f' "${TESTDIR}/wiki/schema.md")"
  printf '%s\n' "${objects}" | grep -q '^- homepage$' \
    || { echo "FAIL: homepage not added to Objects"; cat "${TESTDIR}/wiki/schema.md"; teardown; exit 1; }
  grep -q '^- cro$' "${TESTDIR}/wiki/schema.md" \
    || { echo "FAIL: cro not added to Tag Taxonomy"; teardown; exit 1; }
  if grep -q '(none yet)' "${TESTDIR}/wiki/schema.md"; then
    echo "FAIL: Objects still none yet after 6 hits"; teardown; exit 1
  fi
  echo "PASS: test_six_homepage_pages_add_object_and_tags"
  teardown
}

test_five_pages_do_not_add_object() {
  setup
  local i
  for i in 1 2 3 4 5; do
    write_page "${TESTDIR}/wiki/concepts/home-${i}.md" \
      "Homepage layout ${i}" "[homepage]"
  done
  python3 "${BUILD}" --wiki-root "${TESTDIR}/wiki" --rebuild-all
  python3 "${PATCH}" --wiki-root "${TESTDIR}/wiki"
  objects="$(awk '/^## Objects/{f=1;next} /^## /{f=0} f' "${TESTDIR}/wiki/schema.md")"
  if printf '%s\n' "${objects}" | grep -q '^- homepage$'; then
    echo "FAIL: 5 hits must not add object"; echo "${objects}"; teardown; exit 1
  fi
  echo "PASS: test_five_pages_do_not_add_object"
  teardown
}

test_categories_refresh_from_directories() {
  setup
  mkdir -p "${TESTDIR}/wiki/journal"
  python3 "${PATCH}" --wiki-root "${TESTDIR}/wiki"
  grep -q 'journal/' "${TESTDIR}/wiki/schema.md" \
    || { echo "FAIL: journal category missing"; teardown; exit 1; }
  echo "PASS: test_categories_refresh_from_directories"
  teardown
}

test_six_homepage_pages_add_object_and_tags
test_five_pages_do_not_add_object
test_categories_refresh_from_directories
echo "ALL PASS"
