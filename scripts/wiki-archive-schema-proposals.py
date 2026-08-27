#!/usr/bin/env python3
"""Move leftover schema-proposals into pending archive. Never delete.

Usage:
    wiki-archive-schema-proposals.py --wiki-root <wiki-root>

Missing or empty source exits 0. A second run is a no-op.
"""

from __future__ import annotations

import argparse
import datetime as dt
import sys
from pathlib import Path


def _nonempty(path: Path) -> bool:
    try:
        return any(path.iterdir())
    except FileNotFoundError:
        return False


def archive_schema_proposals(wiki: Path) -> None:
    src = wiki / ".wiki-pending" / "schema-proposals"
    if not src.exists():
        return
    if not _nonempty(src):
        try:
            src.rmdir()
        except OSError:
            pass
        return
    dest_parent = wiki / ".wiki-pending" / "archive"
    dest_parent.mkdir(parents=True, exist_ok=True)
    dest = dest_parent / "schema-proposals"
    if dest.exists():
        stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        dest = dest_parent / f"schema-proposals-{stamp}"
    src.rename(dest)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wiki-root", required=True)
    args = parser.parse_args()
    wiki = Path(args.wiki_root).resolve()
    if not wiki.is_dir():
        print(f"wiki-archive-schema-proposals: not a directory: {wiki}", file=sys.stderr)
        sys.exit(1)
    archive_schema_proposals(wiki)


if __name__ == "__main__":
    main()
