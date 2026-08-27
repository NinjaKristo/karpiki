#!/bin/bash
# Tag keep/drop helper: pages, taxonomy, indexes, ranking, bodies unchanged.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT="${REPO_ROOT}/scripts/wiki-init.sh"
BUILD="${REPO_ROOT}/scripts/wiki-build-index.py"
COLLAPSE="${REPO_ROOT}/scripts/wiki-collapse-tag.py"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "${COLLAPSE}" ]] || fail "wiki-collapse-tag.py missing"

write_page() {
  local path="$1" title="$2" tags="$3" body="$4"
  mkdir -p "$(dirname "${path}")"
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
${body}
EOF
}

test_keep_drop_rewrites_pages_taxonomy_and_index() {
  local dir
  dir="$(mktemp -d)"
  bash "${INIT}" main "${dir}/wiki" >/dev/null
  write_page "${dir}/wiki/concepts/a.md" "Checkout A" "[checkout]" "BODY-A-UNIQUE"
  write_page "${dir}/wiki/concepts/b.md" "Checkout B" "[checkouts, payments]" "BODY-B-UNIQUE"
  python3 "${BUILD}" --wiki-root "${dir}/wiki" --rebuild-all
  python3 "${COLLAPSE}" --wiki-root "${dir}/wiki" --keep checkout --drop checkouts
  grep -q 'tags: \[checkout\]' "${dir}/wiki/concepts/a.md" \
    || { echo "FAIL: page a lost checkout"; rm -rf "${dir}"; exit 1; }
  grep -q 'tags: \[checkout, payments\]' "${dir}/wiki/concepts/b.md" \
    || { echo "FAIL: page b did not collapse checkouts"; cat "${dir}/wiki/concepts/b.md"; rm -rf "${dir}"; exit 1; }
  if grep -q 'checkouts' "${dir}/wiki/concepts/b.md"; then
    echo "FAIL: dropped spelling remains on page b"; rm -rf "${dir}"; exit 1
  fi
  grep -q 'BODY-A-UNIQUE' "${dir}/wiki/concepts/a.md" \
    || { echo "FAIL: body rewritten on a"; rm -rf "${dir}"; exit 1; }
  grep -q 'BODY-B-UNIQUE' "${dir}/wiki/concepts/b.md" \
    || { echo "FAIL: body rewritten on b"; rm -rf "${dir}"; exit 1; }
  grep -q '^- checkout$' "${dir}/wiki/schema.md" \
    || { echo "FAIL: taxonomy missing checkout"; rm -rf "${dir}"; exit 1; }
  if grep -q '^- checkouts$' "${dir}/wiki/schema.md"; then
    echo "FAIL: taxonomy still has checkouts"; rm -rf "${dir}"; exit 1
  fi
  if grep -q '==' "${dir}/wiki/schema.md"; then
    echo "FAIL: helper wrote synonym pairs"; rm -rf "${dir}"; exit 1
  fi
  grep -q '\[checkout' "${dir}/wiki/concepts/_index.md" \
    || { echo "FAIL: index missing kept tag"; rm -rf "${dir}"; exit 1; }
  echo "PASS: test_keep_drop_rewrites_pages_taxonomy_and_index"
  rm -rf "${dir}"
}

test_choose_ranking() {
  local dir
  dir="$(mktemp -d)"
  bash "${INIT}" main "${dir}/wiki" >/dev/null
  python3 - "${dir}/wiki/schema.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
text = text.replace(
    "## Tag Taxonomy (bounded)\n",
    "## Tag Taxonomy (bounded)\n- checkout\n",
    1,
)
path.write_text(text)
PY
  write_page "${dir}/wiki/concepts/a.md" "A" "[checkout]" "a"
  write_page "${dir}/wiki/concepts/b.md" "B" "[checkouts]" "b"
  out="$(python3 "${COLLAPSE}" --wiki-root "${dir}/wiki" --choose checkout checkouts)"
  keep="$(printf '%s\n' "${out}" | sed -n '1p')"
  drop="$(printf '%s\n' "${out}" | sed -n '2p')"
  [[ "${keep}" == "checkout" && "${drop}" == "checkouts" ]] \
    || { echo "FAIL: taxonomy should win; got keep=${keep} drop=${drop}"; rm -rf "${dir}"; exit 1; }

  dir2="$(mktemp -d)"
  bash "${INIT}" main "${dir2}/wiki" >/dev/null
  write_page "${dir2}/wiki/concepts/a.md" "A" "[checkout]" "a"
  write_page "${dir2}/wiki/concepts/b.md" "B" "[checkout]" "b"
  write_page "${dir2}/wiki/concepts/c.md" "C" "[checkouts]" "c"
  out="$(python3 "${COLLAPSE}" --wiki-root "${dir2}/wiki" --choose checkout checkouts)"
  keep="$(printf '%s\n' "${out}" | sed -n '1p')"
  [[ "${keep}" == "checkout" ]] \
    || { echo "FAIL: more uses should win; got ${keep}"; rm -rf "${dir}" "${dir2}"; exit 1; }

  dir3="$(mktemp -d)"
  bash "${INIT}" main "${dir3}/wiki" >/dev/null
  write_page "${dir3}/wiki/concepts/a.md" "A" "[cart]" "a"
  write_page "${dir3}/wiki/concepts/b.md" "B" "[checkout]" "b"
  out="$(python3 "${COLLAPSE}" --wiki-root "${dir3}/wiki" --choose checkout cart)"
  keep="$(printf '%s\n' "${out}" | sed -n '1p')"
  [[ "${keep}" == "cart" ]] \
    || { echo "FAIL: shorter should win; got ${keep}"; rm -rf "${dir}" "${dir2}" "${dir3}"; exit 1; }

  dir4="$(mktemp -d)"
  bash "${INIT}" main "${dir4}/wiki" >/dev/null
  write_page "${dir4}/wiki/concepts/a.md" "A" "[alpha]" "a"
  write_page "${dir4}/wiki/concepts/b.md" "B" "[bravo]" "b"
  out="$(python3 "${COLLAPSE}" --wiki-root "${dir4}/wiki" --choose bravo alpha)"
  keep="$(printf '%s\n' "${out}" | sed -n '1p')"
  [[ "${keep}" == "alpha" ]] \
    || { echo "FAIL: alphabetical should win; got ${keep}"; rm -rf "${dir}" "${dir2}" "${dir3}" "${dir4}"; exit 1; }

  echo "PASS: test_choose_ranking"
  rm -rf "${dir}" "${dir2}" "${dir3}" "${dir4}"
}

test_same_idea_dedupes_both_spellings_on_one_page() {
  local dir
  dir="$(mktemp -d)"
  bash "${INIT}" main "${dir}/wiki" >/dev/null
  write_page "${dir}/wiki/concepts/a.md" "Both" "[checkout, checkouts]" "BODY"
  python3 "${COLLAPSE}" --wiki-root "${dir}/wiki" --same-idea checkout checkouts
  grep -q 'tags: \[checkout\]' "${dir}/wiki/concepts/a.md" \
    || { echo "FAIL: both-spellings page not collapsed"; cat "${dir}/wiki/concepts/a.md"; rm -rf "${dir}"; exit 1; }
  echo "PASS: test_same_idea_dedupes_both_spellings_on_one_page"
  rm -rf "${dir}"
}

test_block_list_tags_collapse() {
  local dir
  dir="$(mktemp -d)"
  bash "${INIT}" main "${dir}/wiki" >/dev/null
  mkdir -p "${dir}/wiki/concepts"
  cat > "${dir}/wiki/concepts/a.md" <<'EOF'
---
title: "Block tags"
type: concepts
tags:
  - checkout
  - checkouts
  - payments
sources: []
summary: "block"
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
BLOCK-BODY
EOF
  python3 "${COLLAPSE}" --wiki-root "${dir}/wiki" --keep checkout --drop checkouts
  grep -q 'tags: \[checkout, payments\]' "${dir}/wiki/concepts/a.md" \
    || { echo "FAIL: block tags not collapsed"; cat "${dir}/wiki/concepts/a.md"; rm -rf "${dir}"; exit 1; }
  if grep -q 'checkouts' "${dir}/wiki/concepts/a.md"; then
    echo "FAIL: dropped spelling remains in block tags"; rm -rf "${dir}"; exit 1
  fi
  grep -q 'BLOCK-BODY' "${dir}/wiki/concepts/a.md" \
    || { echo "FAIL: block-tag body rewritten"; rm -rf "${dir}"; exit 1; }
  echo "PASS: test_block_list_tags_collapse"
  rm -rf "${dir}"
}

test_keep_drop_rewrites_pages_taxonomy_and_index
test_choose_ranking
test_same_idea_dedupes_both_spellings_on_one_page
test_block_list_tags_collapse
echo "ALL PASS"
