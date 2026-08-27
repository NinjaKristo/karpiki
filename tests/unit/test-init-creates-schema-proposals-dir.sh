#!/bin/bash
# Init must not create a schema-proposals inbox.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT="${REPO_ROOT}/scripts/wiki-init.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "${INIT}" ]] || fail "wiki-init.sh missing or not executable"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

bash "${INIT}" main "${TMP}/wiki" >/dev/null

[[ -d "${TMP}/wiki/.wiki-pending" ]] \
  || fail "init must still create .wiki-pending"
if [[ -d "${TMP}/wiki/.wiki-pending/schema-proposals" ]]; then
  fail "init must not create .wiki-pending/schema-proposals"
fi

echo "PASS: wiki-init does not create schema-proposals"
