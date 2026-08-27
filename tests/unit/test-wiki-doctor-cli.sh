#!/bin/bash
# wiki doctor CLI and detached worker contract (no live strong model).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WIKI_BIN="${REPO_ROOT}/bin/wiki"
DISPATCH="${REPO_ROOT}/scripts/wiki_dispatch.py"
INIT="${REPO_ROOT}/scripts/wiki-init.sh"
export WIKI_CONFIG_TEST_ALLOW_CHECKOUT_RUNTIME=1

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "${REPO_ROOT}/scripts/wiki-doctor.sh" ]] || fail "wiki-doctor.sh is not executable"
[[ -x "${REPO_ROOT}/scripts/wiki-complete-doctor.sh" ]] || fail "wiki-complete-doctor.sh is not executable"

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
  cat > "${root}/.wiki-config.local" <<'EOF'
[ingest]
dispatch_mode = "scheduled"
max_processes = 1
default_profile = "test_profile"
heartbeat_seconds = 5
stale_after_seconds = 30
usage_monitor = "off"

[ingest.profiles.test_profile]
provider = "codex"
model = "test-model"
reasoning_effort = "low"

[settings]
auto_commit = false
EOF
}

count_leases() {
  find "$1/.locks/ingest-slots" -maxdepth 1 -type f -name '*.lock' 2>/dev/null | wc -l | tr -d ' '
}

stop_wiki_workers() {
  local wiki="$1"
  local lease pid provider
  for lease in "${wiki}"/.locks/ingest-slots/*.lock; do
    [[ -f "${lease}" ]] || continue
    pid="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("wrapper_pid", "") or "")' "${lease}" 2>/dev/null || true)"
    provider="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("provider_pid", "") or "")' "${lease}" 2>/dev/null || true)"
    [[ "${pid}" =~ ^[0-9]+$ ]] && kill "${pid}" 2>/dev/null || true
    [[ "${provider}" =~ ^[0-9]+$ ]] && kill "${provider}" 2>/dev/null || true
  done
  sleep 0.2
}

wait_for() {
  local i
  for i in $(seq 1 80); do
    if eval "$1"; then
      return 0
    fi
    sleep 0.05
  done
  return 1
}

leases_eq() {
  [[ "$(count_leases "$1")" -eq "$2" ]]
}

test_test_mode_completes_and_is_not_a_stub() {
  local wiki="${TESTDIR}/cli-test"
  make_wiki "${wiki}"
  local out
  out="$(WIKI_DOCTOR_TEST=1 bash "${WIKI_BIN}" doctor "${wiki}" 2>&1)" \
    || fail "wiki doctor test-mode failed: ${out}"
  grep -qi 'not implemented' <<< "${out}" && fail "wiki doctor still says not implemented"
  grep -q '"status":"completed"' "${wiki}/.doctor-runs.jsonl" \
    || fail "test-mode doctor did not write a completed run"
  [[ -d "${wiki}/.wiki-pending/rewrite-jobs" ]] \
    || fail "doctor did not create rewrite-jobs directory"
  echo "PASS: test_test_mode_completes_and_is_not_a_stub"
}

test_failed_helper_does_not_stamp_completed() {
  local wiki="${TESTDIR}/cli-fail"
  make_wiki "${wiki}"
  WIKI_ROOT="${wiki}" bash "${REPO_ROOT}/scripts/wiki-complete-doctor.sh" >/dev/null 2>&1 \
    && fail "complete-doctor without WIKI_RUN_ID should fail"
  [[ ! -f "${wiki}/.doctor-runs.jsonl" ]] \
    || grep -qv '"status":"completed"' "${wiki}/.doctor-runs.jsonl" \
    || fail "failed complete-doctor wrote a completed record"
  echo "PASS: test_failed_helper_does_not_stamp_completed"
}

test_dispatch_spawns_doctor_worker_lease() {
  local wiki="${TESTDIR}/cli-hold"
  make_wiki "${wiki}"
  WIKI_DISPATCH_TEST_MODE=1 \
  WIKI_DISPATCH_TEST_PROVIDER_MODE=hold \
  WIKI_DISPATCH_TEST_PROVIDER_SECONDS=8 \
  WIKI_DISPATCH_TEST_HEARTBEAT_SECONDS=0.1 \
  WIKI_DISPATCH_TEST_NO_REFILL=1 \
    python3 "${DISPATCH}" doctor --wiki "${wiki}" --run-id "doc-hold-1" \
    || fail "dispatch doctor hold spawn failed"
  wait_for 'leases_eq "'"${wiki}"'" 1' \
    || fail "doctor worker did not take a slot lease"
  python3 - "${wiki}/.locks/ingest-slots" <<'PY' || fail "doctor lease is not marked job=doctor"
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
leases = list(root.glob("*.lock"))
assert leases, "no lease"
lease = json.loads(leases[0].read_text())
assert lease.get("job") == "doctor", lease
assert lease.get("run_id") == "doc-hold-1", lease
PY
  grep -q '"status":"completed"' "${wiki}/.doctor-runs.jsonl" 2>/dev/null \
    && fail "hold-mode doctor wrote completed before the worker finished"
  stop_wiki_workers "${wiki}"
  echo "PASS: test_dispatch_spawns_doctor_worker_lease"
}

test_failed_worker_does_not_write_completed() {
  local wiki="${TESTDIR}/cli-transient"
  make_wiki "${wiki}"
  WIKI_DISPATCH_TEST_MODE=1 \
  WIKI_DISPATCH_TEST_PROVIDER_MODE=transient_failure \
  WIKI_DISPATCH_TEST_NO_REFILL=1 \
    python3 "${DISPATCH}" doctor --wiki "${wiki}" --run-id "doc-fail-1" \
    || fail "dispatch doctor spawn on transient_failure should still enqueue"
  wait_for 'leases_eq "'"${wiki}"'" 0 && [[ -f "'"${wiki}"'/.doctor-runs.jsonl" ]]' \
    || fail "failed doctor worker did not finish"
  if grep -q '"status":"completed"' "${wiki}/.doctor-runs.jsonl"; then
    fail "failed doctor wrote a completed record"
  fi
  echo "PASS: test_failed_worker_does_not_write_completed"
}

test_second_doctor_skips_while_leased() {
  local wiki="${TESTDIR}/cli-skip"
  make_wiki "${wiki}"
  WIKI_DISPATCH_TEST_MODE=1 \
  WIKI_DISPATCH_TEST_PROVIDER_MODE=hold \
  WIKI_DISPATCH_TEST_PROVIDER_SECONDS=8 \
  WIKI_DISPATCH_TEST_NO_REFILL=1 \
    python3 "${DISPATCH}" doctor --wiki "${wiki}" --run-id "doc-first" \
    || fail "first doctor spawn failed"
  wait_for 'leases_eq "'"${wiki}"'" 1' || fail "first doctor lease missing"
  local out
  out="$(
    WIKI_DISPATCH_TEST_MODE=1 \
    WIKI_DISPATCH_TEST_PROVIDER_MODE=hold \
    WIKI_DISPATCH_TEST_NO_REFILL=1 \
      python3 "${DISPATCH}" doctor --wiki "${wiki}" --run-id "doc-second"
  )" || fail "second doctor enqueue should exit 0"
  grep -qi 'skipped' <<< "${out}" || fail "second doctor did not skip, got: ${out}"
  [[ "$(count_leases "${wiki}")" -eq 1 ]] || fail "second doctor created another lease"
  stop_wiki_workers "${wiki}"
  echo "PASS: test_second_doctor_skips_while_leased"
}

test_test_mode_completes_and_is_not_a_stub
test_failed_helper_does_not_stamp_completed
test_dispatch_spawns_doctor_worker_lease
test_failed_worker_does_not_write_completed
test_second_doctor_skips_while_leased
echo "ALL PASS"
