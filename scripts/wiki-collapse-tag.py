#!/usr/bin/env python3
"""Collapse two tag spellings to one on pages, indexes, and Tag Taxonomy.

Usage:
    wiki-collapse-tag.py --wiki-root <wiki> --keep <tag> --drop <tag>
    wiki-collapse-tag.py --wiki-root <wiki> --choose <tag-a> <tag-b>
    wiki-collapse-tag.py --wiki-root <wiki> --same-idea <tag-a> <tag-b>
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from wiki_yaml import RESERVED, extract_frontmatter, parse_yaml, split_frontmatter

SKIP_NAMES = {"_index.md", "index.md", "schema.md", "log.md", "README.md"}
TAXONOMY_HEADING = "## Tag Taxonomy (bounded)"
SECTION_RE = re.compile(
    r"(^## [^\n]+\n)(.*?)(?=^## |\Z)",
    re.MULTILINE | re.DOTALL,
)
INLINE_TAGS_RE = re.compile(r"^tags:\s*\[[^\]]*\][^\n]*\n?", re.MULTILINE)
BLOCK_TAGS_RE = re.compile(
    r"^tags:\s*\n(?:[ \t]*-[^\n]*\n)+",
    re.MULTILINE,
)


def _pages(wiki: Path) -> list[Path]:
    found: list[Path] = []
    for path in wiki.rglob("*.md"):
        rel = path.relative_to(wiki)
        if any(part.startswith(".") or part in RESERVED for part in rel.parts[:-1]):
            continue
        if path.name in SKIP_NAMES:
            continue
        found.append(path)
    return found


def _page_tags(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []
    raw = extract_frontmatter(text)
    if not raw:
        return []
    try:
        parsed = parse_yaml(raw)
    except ValueError:
        return []
    tags = parsed.get("tags") or []
    if not isinstance(tags, list):
        return []
    return [str(item) for item in tags if str(item).strip()]


def _taxonomy_tags(schema_text: str) -> list[str]:
    match = None
    for section in SECTION_RE.finditer(schema_text):
        if section.group(1).strip() == TAXONOMY_HEADING:
            match = section.group(2)
            break
    if match is None:
        return []
    tags: list[str] = []
    for line in match.splitlines():
        stripped = line.strip()
        if stripped.startswith("- ") and "==" not in stripped:
            tags.append(stripped[2:].strip())
    return tags


def _uses(wiki: Path) -> dict[str, int]:
    counts: dict[str, int] = {}
    for path in _pages(wiki):
        for tag in _page_tags(path):
            counts[tag] = counts.get(tag, 0) + 1
    return counts


def choose_keeper(
    first: str, second: str, taxonomy: list[str], uses: dict[str, int]
) -> tuple[str, str]:
    tax = set(taxonomy)
    in_first = first in tax
    in_second = second in tax
    if in_first and not in_second:
        return first, second
    if in_second and not in_first:
        return second, first
    use_first = uses.get(first, 0)
    use_second = uses.get(second, 0)
    if use_first != use_second:
        return (first, second) if use_first > use_second else (second, first)
    if len(first) != len(second):
        return (first, second) if len(first) < len(second) else (second, first)
    return (first, second) if first < second else (second, first)


def _collapsed_tags(tags: list[str], keep: str, drop: str) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for tag in tags:
        item = keep if tag == drop else tag
        if item in seen:
            continue
        seen.add(item)
        out.append(item)
    return out


def _rewrite_page_tags(path: Path, keep: str, drop: str) -> bool:
    text = path.read_text(encoding="utf-8")
    opener, fm_block, after = split_frontmatter(text)
    if fm_block is None or after is None or opener is None:
        return False
    tags = _page_tags(path)
    if drop not in tags and keep not in tags:
        return False
    new_tags = _collapsed_tags(tags, keep, drop)
    if new_tags == tags:
        return False
    rendered = "tags: [" + ", ".join(new_tags) + "]\n"
    if INLINE_TAGS_RE.search(fm_block):
        new_fm = INLINE_TAGS_RE.sub(rendered, fm_block, count=1)
    elif BLOCK_TAGS_RE.search(fm_block):
        new_fm = BLOCK_TAGS_RE.sub(rendered, fm_block, count=1)
    else:
        new_fm = fm_block.rstrip() + "\n" + rendered
    path.write_text(opener + new_fm + "\n" + after)
    return True


def _rewrite_taxonomy(schema_text: str, keep: str, drop: str) -> str:
    tags = _taxonomy_tags(schema_text)
    kept: list[str] = []
    seen: set[str] = set()
    for tag in tags:
        item = keep if tag == drop else tag
        if item in seen:
            continue
        seen.add(item)
        kept.append(item)
    if keep not in seen:
        kept.append(keep)
        seen.add(keep)
    intro: list[str] = []
    match_body = ""
    for section in SECTION_RE.finditer(schema_text):
        if section.group(1).strip() == TAXONOMY_HEADING:
            match_body = section.group(2)
            break
    for line in match_body.splitlines():
        stripped = line.strip()
        if stripped.startswith("- "):
            continue
        if stripped:
            intro.append(line.rstrip())
    body_lines = intro + [f"- {tag}" for tag in kept]
    body = "\n".join(body_lines) + "\n"
    pattern = re.compile(
        rf"^{re.escape(TAXONOMY_HEADING)}\n.*?(?=^## |\Z)",
        re.MULTILINE | re.DOTALL,
    )
    replacement = TAXONOMY_HEADING + "\n" + body.rstrip() + "\n\n"
    if pattern.search(schema_text):
        return pattern.sub(replacement, schema_text, count=1)
    return schema_text.rstrip() + "\n\n" + replacement


def _rebuild_indexes(wiki: Path) -> None:
    script = Path(__file__).parent / "wiki-build-index.py"
    subprocess.run(
        [sys.executable, str(script), "--wiki-root", str(wiki), "--rebuild-all"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def apply_collapse(wiki: Path, keep: str, drop: str) -> int:
    changed = 0
    for path in _pages(wiki):
        if _rewrite_page_tags(path, keep, drop):
            changed += 1
    schema = wiki / "schema.md"
    if schema.is_file():
        text = schema.read_text(encoding="utf-8")
        new_text = _rewrite_taxonomy(text, keep, drop)
        if new_text != text:
            schema.write_text(new_text)
            changed += 1
    _rebuild_indexes(wiki)
    return changed


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Collapse two tag spellings to one.")
    parser.add_argument("--wiki-root", required=True)
    parser.add_argument("--keep")
    parser.add_argument("--drop")
    parser.add_argument("--choose", nargs=2, metavar=("TAG_A", "TAG_B"))
    parser.add_argument("--same-idea", nargs=2, metavar=("TAG_A", "TAG_B"))
    args = parser.parse_args(argv)
    wiki = Path(args.wiki_root)
    if not wiki.is_dir():
        print(f"wiki-collapse-tag: wiki root missing: {wiki}", file=sys.stderr)
        return 2
    uses = _uses(wiki)
    taxonomy: list[str] = []
    schema = wiki / "schema.md"
    if schema.is_file():
        taxonomy = _taxonomy_tags(schema.read_text(encoding="utf-8"))
    if args.choose:
        keep, drop = choose_keeper(args.choose[0], args.choose[1], taxonomy, uses)
        print(keep)
        print(drop)
        return 0
    if args.same_idea:
        keep, drop = choose_keeper(args.same_idea[0], args.same_idea[1], taxonomy, uses)
        apply_collapse(wiki, keep, drop)
        print(f"kept {keep}; dropped {drop}")
        return 0
    if not args.keep or not args.drop:
        print("wiki-collapse-tag: --keep and --drop, --choose, or --same-idea required", file=sys.stderr)
        return 2
    if args.keep == args.drop:
        print("wiki-collapse-tag: keep and drop must differ", file=sys.stderr)
        return 2
    apply_collapse(wiki, args.keep, args.drop)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
