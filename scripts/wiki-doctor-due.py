#!/usr/bin/env python3
"""Whether a wiki is due for a detached doctor census.

Reads Doctor cadence from schema.md (default 10, 20, 50, 100). Counts
completed ingestions since the last successful doctor. Intervals apply in
order; the last number repeats. Skip, failed, and other non-completed ingest
statuses do not count. A failed doctor does not advance the interval.

Exit 0 and print "due" when a census should run. Exit 1 and print "not-due"
otherwise. Exit 2 on usage or I/O errors.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

DEFAULT_CADENCE = (10, 20, 50, 100)
INDEX_THRESHOLD_BYTES = 8192
CADENCE_RE = re.compile(
    r"^-\s*Doctor cadence:\s*([0-9]+(?:\s*,\s*[0-9]+)*)\s*$",
    re.IGNORECASE | re.MULTILINE,
)


def _read_jsonl(path: Path) -> list[dict]:
    try:
        raw = path.read_bytes()
    except FileNotFoundError:
        return []
    except OSError as exc:
        raise SystemExit(f"wiki-doctor-due: cannot read {path}: {exc}") from exc
    events: list[dict] = []
    for chunk in raw.split(b"\n"):
        if not chunk.strip():
            continue
        try:
            event = json.loads(chunk.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
        if isinstance(event, dict):
            events.append(event)
    return events


def parse_cadence(schema_text: str) -> tuple[int, ...]:
    match = CADENCE_RE.search(schema_text)
    if not match:
        return DEFAULT_CADENCE
    values = tuple(int(part.strip()) for part in match.group(1).split(",") if part.strip())
    if not values or any(v <= 0 for v in values):
        return DEFAULT_CADENCE
    return values


def interval_for(successful_doctors: int, cadence: tuple[int, ...]) -> int:
    if successful_doctors >= len(cadence):
        return cadence[-1]
    return cadence[successful_doctors]


def is_due(
    ingest_events: list[dict],
    doctor_events: list[dict],
    cadence: tuple[int, ...],
    *,
    fat_index: bool = False,
) -> bool:
    doctors = [e for e in doctor_events if e.get("status") == "completed"]
    doctors.sort(key=lambda e: str(e.get("at") or ""))
    last_doctor_at = str(doctors[-1].get("at") or "") if doctors else ""
    completed = [
        e
        for e in ingest_events
        if e.get("status") == "completed"
        and (not last_doctor_at or str(e.get("at") or "") > last_doctor_at)
    ]
    needed = interval_for(len(doctors), cadence)
    if len(completed) >= needed:
        return True
    if fat_index and not doctors:
        return True
    return False


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Print due/not-due for wiki doctor cadence.")
    parser.add_argument("--wiki-root", required=True)
    args = parser.parse_args(argv)
    root = Path(args.wiki_root)
    if not root.is_dir():
        print(f"wiki-doctor-due: wiki root missing: {root}", file=sys.stderr)
        return 2
    schema = root / "schema.md"
    try:
        schema_text = schema.read_text() if schema.is_file() else ""
    except OSError as exc:
        print(f"wiki-doctor-due: cannot read schema.md: {exc}", file=sys.stderr)
        return 2
    cadence = parse_cadence(schema_text)
    ingest_events = _read_jsonl(root / ".ingest-runs.jsonl")
    doctor_events = _read_jsonl(root / ".doctor-runs.jsonl")
    index_path = root / "concepts" / "_index.md"
    fat_index = False
    try:
        fat_index = index_path.is_file() and index_path.stat().st_size > INDEX_THRESHOLD_BYTES
    except OSError:
        fat_index = False
    if is_due(ingest_events, doctor_events, cadence, fat_index=fat_index):
        print("due")
        return 0
    print("not-due")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
