#!/bin/bash
# After ingest complete, dispatcher enqueues doctor only when due-check is true.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DISPATCH="${REPO_ROOT}/scripts/wiki_dispatch.py"
INIT="${REPO_ROOT}/scripts/wiki-init.sh"
export WIKI_CONFIG_TEST_ALLOW_CHECKOUT_RUNTIME=1
export PYTHONPATH="${REPO_ROOT}/scripts"

fail() { echo "FAIL: $*" >&2; exit 1; }

TESTDIR="$(mktemp -d)"
TESTDIR="$(cd "${TESTDIR}" && pwd -P)"
export WIKI_CONFIG_HOME="${TESTDIR}/config-home"
cleanup() {
  local lease pid provider
  while IFS= read -r lease; do
    [[ -n "${lease}" ]] || continue
    pid="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("wrapper_pid", "") or "")' "${lease}" 2>/dev/null || true)"
    provider="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("provider_pid", "") or "")' "${lease}" 2>/dev/null || true)"
    [[ "${pid}" =~ ^[0-9]+$ ]] && kill "${pid}" 2>/dev/null || true
    [[ "${provider}" =~ ^[0-9]+$ ]] && kill "${provider}" 2>/dev/null || true
  done < <(find "${TESTDIR}" -type f -path '*/.locks/ingest-slots/*.lock' 2>/dev/null || true)
  rm -rf "${TESTDIR}"
}
trap cleanup EXIT

make_wiki() {
  local root="$1"
  bash "${INIT}" main "${root}" >/dev/null
  printf '{}\n' > "${root}/.manifest.json"
  cat > "${root}/.wiki-config.local" <<'EOF'
[ingest]
dispatch_mode = "scheduled"
max_processes = 1
default_profile = "p"
heartbeat_seconds = 5
stale_after_seconds = 30
usage_monitor = "off"
max_attempts = 4
[ingest.profiles.p]
provider = "codex"
model = "test"
reasoning_effort = "low"
[settings]
auto_commit = false
EOF
}

seed_completed_ingests() {
  local root="$1"
  local count="$2"
  local i
  : > "${root}/.ingest-runs.jsonl"
  for i in $(seq 1 "${count}"); do
    printf '%s\n' "{\"attempt\":1,\"at\":\"2026-08-01T00:00:$(printf '%02d' "${i}")Z\",\"capture\":\"prior-${i}.md\",\"run_id\":\"in-prior-${i}\",\"status\":\"completed\"}" \
      >> "${root}/.ingest-runs.jsonl"
  done
}

wait_for() {
  local i
  for i in $(seq 1 100); do
    if eval "$1"; then
      return 0
    fi
    sleep 0.05
  done
  return 1
}

run_complete_tick() {
  local wiki="$1"
  shift
  env WIKI_DISPATCH_TEST_MODE=1 \
    WIKI_DISPATCH_TEST_PROVIDER_MODE=complete_success \
    WIKI_DISPATCH_TEST_NO_REFILL=1 \
    "$@" \
    python3 "${DISPATCH}" tick --wiki "${wiki}" --source manual
}

test_due_true_enqueues_doctor() {
  local wiki="${TESTDIR}/due-true"
  make_wiki "${wiki}"
  seed_completed_ingests "${wiki}" 9
  printf '%s\n' '---' 'title: "Due true"' '---' > "${wiki}/.wiki-pending/next.md"
  run_complete_tick "${wiki}" \
    || fail "ingest complete on due wiki should exit 0"
  wait_for '[[ -f "'"${wiki}"'/.doctor-runs.jsonl" ]] && grep -q "\"status\":\"started\"" "'"${wiki}"'/.doctor-runs.jsonl" 2>/dev/null' \
    || fail "due ingest complete did not enqueue a doctor"
  wait_for 'grep -q "\"status\":\"completed\"" "'"${wiki}"'/.ingest-runs.jsonl" 2>/dev/null' \
    || fail "due ingest complete did not record ingest completed"
  echo "PASS: test_due_true_enqueues_doctor"
}

test_due_false_does_not_enqueue_doctor() {
  local wiki="${TESTDIR}/due-false"
  make_wiki "${wiki}"
  printf '%s\n' '---' 'title: "Due false"' '---' > "${wiki}/.wiki-pending/next.md"
  run_complete_tick "${wiki}" \
    || fail "ingest complete on not-due wiki should exit 0"
  wait_for 'grep -q "\"status\":\"completed\"" "'"${wiki}"'/.ingest-runs.jsonl" 2>/dev/null' \
    || fail "not-due ingest complete did not record ingest completed"
  if [[ -f "${wiki}/.doctor-runs.jsonl" ]] && grep -q '"status":"started"' "${wiki}/.doctor-runs.jsonl"; then
    fail "not-due ingest complete enqueued a doctor"
  fi
  echo "PASS: test_due_false_does_not_enqueue_doctor"
}

test_ingest_complete_zero_when_doctor_enqueue_fails() {
  local wiki="${TESTDIR}/due-fail"
  make_wiki "${wiki}"
  seed_completed_ingests "${wiki}" 9
  printf '%s\n' '---' 'title: "Due fail"' '---' > "${wiki}/.wiki-pending/next.md"
  run_complete_tick "${wiki}" WIKI_DISPATCH_TEST_DOCTOR_ENQUEUE_FAIL=1 \
    || fail "ingest complete must exit 0 when doctor enqueue fails"
  wait_for 'grep -q "\"status\":\"completed\"" "'"${wiki}"'/.ingest-runs.jsonl" 2>/dev/null' \
    || fail "failed doctor enqueue lost the ingest completion"
  if [[ -f "${wiki}/.doctor-runs.jsonl" ]] && grep -q '"status":"started"' "${wiki}/.doctor-runs.jsonl"; then
    fail "failed doctor enqueue still started a doctor"
  fi
  echo "PASS: test_ingest_complete_zero_when_doctor_enqueue_fails"
}

test_due_true_skips_when_doctor_already_leased() {
  local wiki="${TESTDIR}/due-leased"
  make_wiki "${wiki}"
  WIKI_DISPATCH_TEST_MODE=1 \
  WIKI_DISPATCH_TEST_PROVIDER_MODE=hold \
  WIKI_DISPATCH_TEST_PROVIDER_SECONDS=8 \
  WIKI_DISPATCH_TEST_NO_REFILL=1 \
    python3 "${DISPATCH}" doctor --wiki "${wiki}" --run-id "doc-held" >/dev/null \
    || fail "setup doctor lease failed"
  wait_for '[[ -f "'"${wiki}"'/.locks/ingest-slots/1.lock" ]]' \
    || fail "held doctor lease missing"
  seed_completed_ingests "${wiki}" 10
  python3 - "${wiki}" <<'PY' || fail "ingest complete path must skip leased doctor and stay zero"
import os, sys
from pathlib import Path
from wiki_config import validate_runtime_config
from wiki_dispatch import maybe_enqueue_doctor
os.environ["WIKI_DISPATCH_TEST_MODE"] = "1"
os.environ["WIKI_DISPATCH_TEST_NO_REFILL"] = "1"
root = Path(sys.argv[1])
config = validate_runtime_config(root)
assert maybe_enqueue_doctor(root, config) == "skipped"
PY
  echo "PASS: test_due_true_skips_when_doctor_already_leased"
}

test_due_true_enqueues_doctor
test_due_false_does_not_enqueue_doctor
test_ingest_complete_zero_when_doctor_enqueue_fails
test_due_true_skips_when_doctor_already_leased
echo "ALL PASS"
