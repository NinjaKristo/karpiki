#!/bin/bash
# On-demand detached doctor census.
#
# Usage:
#   wiki-doctor.sh              — cwd-resolved wiki
#   wiki-doctor.sh <wiki-path>  — explicit wiki

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/wiki-lib.sh"

doctor_one_wiki() {
  local wiki="$1"
  [[ -d "${wiki}" ]] || { echo >&2 "wiki doctor: wiki path does not exist: ${wiki}"; return 1; }
  [[ -f "${wiki}/.wiki-config" ]] || { echo >&2 "wiki doctor: not a wiki (no .wiki-config): ${wiki}"; return 1; }
  mkdir -p "${wiki}/.locks" "${wiki}/.wiki-pending/rewrite-jobs"
  python3 "${SCRIPT_DIR}/wiki-archive-schema-proposals.py" --wiki-root "${wiki}" \
    || return 1
  local run_id
  run_id="doc-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local start
  start="$(
    WIKI_DOC_TS="${ts}" WIKI_DOC_RUN="${run_id}" python3 <<'PY'
import json, os
print(json.dumps({
    "run_id": os.environ["WIKI_DOC_RUN"],
    "status": "started",
    "at": os.environ["WIKI_DOC_TS"],
}, separators=(",", ":")))
PY
  )"
  printf '%s\n' "${start}" >> "${wiki}/.doctor-runs.jsonl"
  export WIKI_ROOT="${wiki}"
  export WIKI_RUN_ID="${run_id}"
  export WIKI_PLUGIN_ROOT="${REPO_ROOT}"
  export WIKI_JOB="doctor"
  if [[ "${WIKI_DOCTOR_TEST:-}" == "1" ]]; then
    bash "${SCRIPT_DIR}/wiki-complete-doctor.sh" || return 1
    echo "wiki doctor: completed ${run_id}"
    return 0
  fi
  python3 "${SCRIPT_DIR}/wiki_dispatch.py" doctor --wiki "${wiki}" --run-id "${run_id}" \
    || return 1
}

if [[ $# -eq 0 ]]; then
  resolver_out="$(bash "${SCRIPT_DIR}/wiki-resolve.sh" 2>/dev/null)" && resolver_exit=0 || resolver_exit=$?
  if [[ "${resolver_exit}" != 0 ]]; then
    echo >&2 "wiki doctor: resolver exit ${resolver_exit}; cannot determine target wiki."
    exit 1
  fi
  while IFS= read -r wiki_path; do
    [[ -n "${wiki_path}" ]] || continue
    doctor_one_wiki "${wiki_path}" || exit 1
  done <<< "${resolver_out}"
else
  doctor_one_wiki "$1" || exit 1
fi

exit 0
