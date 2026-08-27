#!/bin/bash
# This repository is a plugin in marketplace toolboxmd, not the marketplace.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

python3 - "${REPO_ROOT}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
version = (root / "VERSION").read_text().strip()
codex_path = root / ".codex-plugin" / "plugin.json"
claude_path = root / ".claude-plugin" / "plugin.json"
grok_path = root / ".grok-plugin" / "plugin.json"
hooks_path = root / "hooks" / "hooks.json"

for path in (codex_path, claude_path, grok_path, hooks_path):
    if not path.is_file():
        raise SystemExit(f"required packaging file missing: {path.relative_to(root)}")

codex = json.loads(codex_path.read_text())
claude = json.loads(claude_path.read_text())
grok = json.loads(grok_path.read_text())
hooks = json.loads(hooks_path.read_text())

for manifest, label in ((codex, "Codex"), (claude, "Claude"), (grok, "Grok")):
    if manifest.get("name") != "karpathy-wiki":
        raise SystemExit(f"{label} plugin name must be karpathy-wiki")
    if manifest.get("version") != version:
        raise SystemExit(f"{label} plugin version must equal VERSION")

if codex.get("skills") != "./skills/":
    raise SystemExit("Codex manifest must expose ./skills/")

forbidden_names = {"toolboxmd", "karpathy-wiki-local"}
for market in (
    root / ".agents" / "plugins" / "marketplace.json",
    root / ".claude-plugin" / "marketplace.json",
    root / ".grok-plugin" / "marketplace.json",
):
    if not market.is_file():
        continue
    name = json.loads(market.read_text()).get("name")
    if name in forbidden_names:
        raise SystemExit(
            f"{market.relative_to(root)} must not advertise marketplace {name}"
        )

skill_dirs = sorted(path.parent for path in (root / "skills").glob("*/SKILL.md"))
if not skill_dirs:
    raise SystemExit("plugin exposes no skills")

hook_map = hooks.get("hooks", {})
if "SessionStart" not in hook_map:
    raise SystemExit("hooks/hooks.json is missing SessionStart")
if "Stop" in hook_map:
    raise SystemExit("Stop must not gate the scheduler-owned capture queue")

commands = [
    hook.get("command", "")
    for groups in hook_map.values()
    for group in groups
    for hook in group.get("hooks", [])
    if hook.get("type") == "command"
]
if not commands:
    raise SystemExit("hooks/hooks.json has no command hooks")
if not all("${CLAUDE_PLUGIN_ROOT}/" in command for command in commands):
    raise SystemExit("hook commands must resolve from the plugin root")

print("PASS: three-host plugin manifests, VERSION, hooks; not a marketplace")
PY
