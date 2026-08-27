#!/bin/bash
# Fat _index.md is an ingest-issue for doctor, not a schema-proposal file.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SKILL="${REPO_ROOT}/skills/karpathy-wiki-ingest/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "${SKILL}" ]] || fail "ingest skill missing"
grep -q '8192' "${SKILL}" || fail "ingest skill must name the 8192-byte index threshold"
grep -q 'schema-drift' "${SKILL}" || fail "fat index must log schema-drift"
if grep -q 'index-split.md' "${SKILL}"; then
  fail "ingest skill still files index-split captures"
fi
if grep -q '.wiki-pending/schema-proposals' "${SKILL}"; then
  fail "ingest skill still writes schema-proposals for index size"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
mkdir -p "${tmp}/wiki/projects/a/b/c" "${tmp}/wiki/raw"
touch "${tmp}/wiki/.wiki-config"
for i in $(seq 1 100); do
  cat > "${tmp}/wiki/projects/a/b/c/page${i}.md" <<EOF
---
title: "Page ${i} with a long descriptive title that contributes to index size"
type: projects
tags: []
sources: []
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
Long body paragraph for entry ${i}. word word word word word word word word word word
EOF
done
python3 "${REPO_ROOT}/scripts/wiki-build-index.py" --wiki-root "${tmp}/wiki" --rebuild-all
size=$(wc -c < "${tmp}/wiki/projects/a/b/c/_index.md")
if [[ "${size}" -le 8192 ]]; then
  fail "expected projects/a/b/c/_index.md to exceed 8 KB; got ${size}"
fi

echo "PASS: fat _index.md is schema-drift, not a schema-proposal write"
