#!/bin/bash
# Doctor-due helper: cadence × completed ingestions × successful doctors.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DUE="${REPO_ROOT}/scripts/wiki-doctor-due.py"
INIT="${REPO_ROOT}/scripts/wiki-init.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "${DUE}" ]] || fail "wiki-doctor-due.py missing"

setup() {
  TESTDIR="$(mktemp -d)"
  bash "${INIT}" main "${TESTDIR}/wiki" >/dev/null
}

teardown() { rm -rf "${TESTDIR}"; }

append_ingest() {
  local status="$1"
  local at="$2"
  printf '%s\n' "{\"run_id\":\"in-${at}\",\"capture\":\"c.md\",\"status\":\"${status}\",\"at\":\"${at}\"}" \
    >> "${TESTDIR}/wiki/.ingest-runs.jsonl"
}

append_doctor() {
  local status="$1"
  local at="$2"
  printf '%s\n' "{\"run_id\":\"doc-${at}\",\"status\":\"${status}\",\"at\":\"${at}\"}" \
    >> "${TESTDIR}/wiki/.doctor-runs.jsonl"
}

expect() {
  local want="$1"
  local out rc
  set +e
  out="$(python3 "${DUE}" --wiki-root "${TESTDIR}/wiki" 2>&1)"
  rc=$?
  set -e
  if [[ "${want}" == "due" ]]; then
    [[ "${rc}" -eq 0 && "${out}" == "due" ]] || fail "want due, got rc=${rc} out=${out}"
  else
    [[ "${rc}" -eq 1 && "${out}" == "not-due" ]] || fail "want not-due, got rc=${rc} out=${out}"
  fi
}

test_zero_completed_not_due() {
  setup
  expect not-due
  echo "PASS: test_zero_completed_not_due"
  teardown
}

test_ten_completed_never_doctored_due() {
  setup
  local i
  for i in $(seq 1 10); do
    append_ingest completed "2026-08-01T00:00:$(printf '%02d' "${i}")Z"
  done
  expect due
  echo "PASS: test_ten_completed_never_doctored_due"
  teardown
}

test_skip_and_failed_do_not_count() {
  setup
  local i
  for i in $(seq 1 9); do
    append_ingest completed "2026-08-01T00:00:$(printf '%02d' "${i}")Z"
  done
  append_ingest skip "2026-08-01T00:01:00Z"
  append_ingest failed "2026-08-01T00:02:00Z"
  expect not-due
  echo "PASS: test_skip_and_failed_do_not_count"
  teardown
}

test_after_one_doctor_interval_is_twenty() {
  setup
  local i
  for i in $(seq 1 10); do
    append_ingest completed "2026-08-01T00:00:$(printf '%02d' "${i}")Z"
  done
  append_doctor completed "2026-08-01T00:10:00Z"
  for i in $(seq 1 19); do
    append_ingest completed "2026-08-01T01:00:$(printf '%02d' "${i}")Z"
  done
  expect not-due
  append_ingest completed "2026-08-01T01:00:20Z"
  expect due
  echo "PASS: test_after_one_doctor_interval_is_twenty"
  teardown
}

test_failed_doctor_does_not_advance_interval() {
  setup
  local i
  for i in $(seq 1 10); do
    append_ingest completed "2026-08-01T00:00:$(printf '%02d' "${i}")Z"
  done
  append_doctor failed "2026-08-01T00:10:00Z"
  expect due
  echo "PASS: test_failed_doctor_does_not_advance_interval"
  teardown
}

test_third_plus_interval_is_last_number() {
  setup
  local i
  for i in $(seq 1 10); do
    append_ingest completed "2026-08-01T00:00:$(printf '%02d' "${i}")Z"
  done
  append_doctor completed "2026-08-01T00:10:00Z"
  for i in $(seq 1 20); do
    append_ingest completed "2026-08-01T01:00:$(printf '%02d' "${i}")Z"
  done
  append_doctor completed "2026-08-01T01:10:00Z"
  for i in $(seq 1 50); do
    append_ingest completed "$(printf '2026-08-01T02:%02d:%02dZ' "$((i / 60))" "$((i % 60))")"
  done
  # third successful doctor uses last cadence number 100
  append_doctor completed "2026-08-01T03:10:00Z"
  for i in $(seq 1 99); do
    append_ingest completed "$(printf '2026-08-01T04:%02d:%02dZ' "$((i / 60))" "$((i % 60))")"
  done
  expect not-due
  append_ingest completed "2026-08-01T05:00:00Z"
  expect due
  echo "PASS: test_third_plus_interval_is_last_number"
  teardown
}

test_missing_cadence_uses_default() {
  setup
  printf '# Schema\n' > "${TESTDIR}/wiki/schema.md"
  local i
  for i in $(seq 1 10); do
    append_ingest completed "2026-08-01T00:00:$(printf '%02d' "${i}")Z"
  done
  expect due
  echo "PASS: test_missing_cadence_uses_default"
  teardown
}

test_zero_completed_not_due
test_ten_completed_never_doctored_due
test_skip_and_failed_do_not_count
test_after_one_doctor_interval_is_twenty
test_failed_doctor_does_not_advance_interval
test_third_plus_interval_is_last_number
test_missing_cadence_uses_default
echo "ALL PASS"
