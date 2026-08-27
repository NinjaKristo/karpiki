#!/usr/bin/env python3
"""Patch schema.md Objects, Tag Taxonomy, and Categories from live indexes.

Usage:
    wiki-schema-patch.py --wiki-root <wiki-root>

Lock: .locks/schema-md.lock (exclusive create). Exit 0 if nothing changed.
"""

from __future__ import annotations

import argparse
import importlib.util
import re
import sys
import time
from pathlib import Path

_DISCOVER_PATH = Path(__file__).parent / "wiki-discover.py"
_spec = importlib.util.spec_from_file_location("wiki_discover", _DISCOVER_PATH)
_discover_mod = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(_discover_mod)
discover = _discover_mod.discover

OBJECT_HIT_THRESHOLD = 6
ENTRY_RE = re.compile(r"^- \[([^\]]+)\]\([^)]+\)(?: — (.*))?$")
TAG_SUFFIX_RE = re.compile(r"\[([^\]]+)\]\s*$")
TOKEN_RE = re.compile(r"[A-Za-z][A-Za-z0-9]*")
SECTION_RE = re.compile(
    r"(^## [^\n]+\n)(.*?)(?=^## |\Z)",
    re.MULTILINE | re.DOTALL,
)


def _acquire_lock(wiki: Path) -> Path:
    lockdir = wiki / ".locks"
    lockdir.mkdir(exist_ok=True)
    lockfile = lockdir / "schema-md.lock"
    deadline = time.time() + 30
    while time.time() < deadline:
        try:
            with lockfile.open("x") as handle:
                handle.write(f"schema-patch:{time.time()}\n")
            return lockfile
        except FileExistsError:
            time.sleep(0.05)
    raise TimeoutError("lock timeout: schema.md")


def _index_entries(wiki: Path) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    for index in wiki.rglob("_index.md"):
        if any(part.startswith(".") for part in index.relative_to(wiki).parts):
            continue
        for line in index.read_text(errors="replace").splitlines():
            match = ENTRY_RE.match(line)
            if not match:
                continue
            title = match.group(1)
            rest = match.group(2) or ""
            entries.append((title, rest))
    return entries


def _object_token(title: str) -> str | None:
    match = TOKEN_RE.search(title)
    if not match:
        return None
    return match.group(0).lower()


def _tags_from_rest(rest: str) -> list[str]:
    match = TAG_SUFFIX_RE.search(rest)
    if not match:
        return []
    return [part.strip() for part in match.group(1).split(",") if part.strip()]


def _blob(title: str, rest: str) -> str:
    return f"{title} {rest}".lower()


def _section(text: str, heading: str) -> str | None:
    for match in SECTION_RE.finditer(text):
        if match.group(1).strip() == heading:
            return match.group(2)
    return None


def _replace_section(text: str, heading: str, body: str) -> str:
    pattern = re.compile(
        rf"^{re.escape(heading)}\n.*?(?=^## |\Z)",
        re.MULTILINE | re.DOTALL,
    )
    replacement = heading + "\n" + body.rstrip() + "\n\n"
    if pattern.search(text):
        return pattern.sub(replacement, text, count=1)
    return text.rstrip() + "\n\n" + replacement


def _objects_body(tokens: list[str]) -> str:
    if not tokens:
        return "(none yet)\n"
    return "".join(f"- {token}\n" for token in tokens)


def _taxonomy_body(existing: str, tags: list[str]) -> str:
    lines = [line.rstrip() for line in existing.splitlines()]
    present = {line[2:].strip() for line in lines if line.startswith("- ")}
    out = []
    for line in lines:
        if line.strip() == "":
            continue
        out.append(line)
    for tag in tags:
        if tag not in present:
            out.append(f"- {tag}")
            present.add(tag)
    if not out:
        return "Tags are evolved by the ingester; propose changes via schema edits, not ad-hoc.\n"
    return "\n".join(out) + "\n"


def _categories_body(names: list[str]) -> str:
    return "".join(f"- `{name}/`\n" for name in names)


def patch_schema(wiki: Path) -> bool:
    schema_path = wiki / "schema.md"
    if not schema_path.is_file():
        return False
    text = schema_path.read_text()
    entries = _index_entries(wiki)
    token_hits: dict[str, int] = {}
    tags: set[str] = set()
    for title, rest in entries:
        token = _object_token(title)
        blob = _blob(title, rest)
        if token:
            token_hits[token] = token_hits.get(token, 0) + (1 if token in blob else 0)
        tags.update(_tags_from_rest(rest))
    objects = sorted(token for token, hits in token_hits.items() if hits >= OBJECT_HIT_THRESHOLD)
    existing_objects = _section(text, "## Objects") or ""
    already = [
        line[2:].strip()
        for line in existing_objects.splitlines()
        if line.startswith("- ")
    ]
    merged_objects = sorted(set(already) | set(objects))
    discovered = discover(wiki).get("categories") or []
    new_text = text
    new_text = _replace_section(new_text, "## Objects", _objects_body(merged_objects))
    taxonomy = _section(new_text, "## Tag Taxonomy (bounded)") or ""
    new_text = _replace_section(
        new_text,
        "## Tag Taxonomy (bounded)",
        _taxonomy_body(taxonomy, sorted(tags)),
    )
    new_text = _replace_section(new_text, "## Categories", _categories_body(discovered))
    if new_text == text:
        return False
    tmp = schema_path.with_suffix(".md.tmp")
    tmp.write_text(new_text)
    tmp.replace(schema_path)
    return True


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Patch schema.md from live wiki indexes.")
    parser.add_argument("--wiki-root", required=True)
    args = parser.parse_args(argv)
    wiki = Path(args.wiki_root)
    if not wiki.is_dir():
        print(f"wiki-schema-patch: wiki root missing: {wiki}", file=sys.stderr)
        return 2
    lockfile = None
    try:
        lockfile = _acquire_lock(wiki)
        patch_schema(wiki)
    except TimeoutError as exc:
        print(f"wiki-schema-patch: {exc}", file=sys.stderr)
        return 1
    finally:
        if lockfile is not None:
            lockfile.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
