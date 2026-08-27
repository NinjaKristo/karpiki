#!/bin/bash
# GROK_PLUGIN_ROOT must not take the Claude-only nested JSON branch, even when
# Grok also sets a Claude plugin-root alias.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOOK="${REPO_ROOT}/hooks/session-start"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "${HOOK}" ]] || fail "hook missing"

output=$(env -u WIKI_CAPTURE -u CLAUDE_AGENT_PARENT -u CURSOR_PLUGIN_ROOT -u COPILOT_CLI \
  GROK_PLUGIN_ROOT="${REPO_ROOT}" \
  CLAUDE_PLUGIN_ROOT="${REPO_ROOT}" \
  bash "${HOOK}" 2>/dev/null || true)

echo "${output}" | grep -q 'additionalContext' \
  || fail "Grok branch did not emit additionalContext. Output: ${output:0:200}"
if echo "${output}" | grep -q '"hookSpecificOutput"'; then
  fail "Grok branch emitted Claude-only hookSpecificOutput"
fi
if echo "${output}" | grep -q '"additional_context"'; then
  fail "Grok branch emitted Cursor additional_context"
fi

echo "PASS: GROK_PLUGIN_ROOT uses SDK additionalContext, not Claude nested JSON"
