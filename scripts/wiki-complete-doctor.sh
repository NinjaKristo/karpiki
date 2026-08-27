#!/bin/bash
# Stamp a successful doctor census.
#
# Required environment: WIKI_ROOT, WIKI_RUN_ID

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/wiki-lib.sh"

wiki="${WIKI_ROOT:-}"
run_id="${WIKI_RUN_ID:-}"

[[ -n "${wiki}" ]] || { echo >&2 "wiki complete-doctor: WIKI_ROOT is required"; exit 1; }
[[ -n "${run_id}" ]] || { echo >&2 "wiki complete-doctor: WIKI_RUN_ID is required"; exit 1; }
wiki="$(cd "${wiki}" 2>/dev/null && pwd -P)" || {
  echo >&2 "wiki complete-doctor: WIKI_ROOT does not exist"
  exit 1
}

mkdir -p "${wiki}/.locks" "${wiki}/.wiki-pending/rewrite-jobs"
lock="${wiki}/.locks/doctor-runs.lock"
log="${wiki}/.doctor-runs.jsonl"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

line="$(
  WIKI_DOC_TS="${ts}" WIKI_DOC_RUN="${run_id}" python3 <<'PY'
import json, os
print(json.dumps({
    "run_id": os.environ["WIKI_DOC_RUN"],
    "status": "completed",
    "at": os.environ["WIKI_DOC_TS"],
}, separators=(",", ":")))
PY
)"

if command -v flock >/dev/null 2>&1; then
  flock "${lock}" bash -c "printf '%s\\n' \"\$1\" >> \"\$2\"" _ "${line}" "${log}"
else
  printf '%s\n' "${line}" >> "${log}"
fi

exit 0
