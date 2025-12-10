#!/usr/bin/env python3
"""
Generate a compact SQLite database (kanji.sqlite) from KanjiVG plus JLPT tags and keyword metadata.

Tables
------
- kanji(id TEXT PRIMARY KEY, char TEXT, stroke_count INTEGER, keyword TEXT)
- kanji_tags(kanji_id TEXT, tag TEXT)
- strokes(kanji_id TEXT, stroke_index INTEGER, stroke_id TEXT, points BLOB)

Stroke storage
--------------
Each stroke is stored as a fixed-size Float32 blob (512 bytes):
64 sampled points * 2 axes * 4 bytes. Coordinates are normalized to 0..1 just
like the previous JSON pipeline.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import sqlite3
import struct
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List

SAMPLES_PER_STROKE = 64
FLOATS_PER_STROKE = SAMPLES_PER_STROKE * 2
BYTES_PER_STROKE = FLOATS_PER_STROKE * 4

SCRIPT_DIR = Path(__file__).resolve().parent


# --- Module loading helpers -------------------------------------------------
def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Unable to load module {name} from {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # type: ignore[call-arg]
    return module


kanj_conv = load_module("kanj_conv", SCRIPT_DIR / "kanj-conv.py")
add_tags_mod = load_module("add_tags_mod", SCRIPT_DIR / "add_tags.py")
add_keywords_mod = load_module("add_keywords_mod", SCRIPT_DIR / "add_keywords.py")


# --- Pipeline steps ---------------------------------------------------------
def convert_kanjivg(input_path: Path, samples: int, normalize_size: float, verbose: bool) -> List[dict]:
    files = kanj_conv.collect_files(str(input_path))
    if verbose:
        print(f"[1/4] Converting KanjiVG -> strokes from {len(files)} file(s)...")

    all_entries: List[dict] = []
    for f in files:
        try:
            tree = kanj_conv.load_xml(f)
            entries = kanj_conv.extract_kanji_from_tree(
                tree,
                samples=samples,
                do_normalize=True,
                size=normalize_size,
                source_filename=f,
            )
            all_entries.extend(entries)
        except Exception as exc:  # pragma: no cover - defensive
            print(f"  ! Skipping {f}: {exc}", file=sys.stderr)
    if verbose:
        print(f"    ✓ Converted {len(all_entries)} kanji")
    return all_entries


def load_jlpt_lookup(path: Path) -> Dict[str, int]:
    with path.open("r", encoding="utf-8") as f:
        jlpt_data: Dict[str, Dict[str, Any]] = json.load(f)
    return {
        k: v.get("jlpt")
        for k, v in jlpt_data.items()
        if isinstance(v, dict) and "jlpt" in v
    }


def annotate_tags(entries: Iterable[dict], jlpt_lookup: Dict[str, int], verbose: bool) -> List[dict]:
    tagged: List[dict] = []
    for entry in entries:
        char = entry.get("kanji") or entry.get("char") or ""
        if not char:
            continue
        tags = add_tags_mod.tags_for_entry(char, entry, jlpt_lookup)
        if not tags:
            # Skip entries without tags to match the previous pipeline behavior
            continue
        enriched = dict(entry)
        enriched["tags"] = tags
        tagged.append(enriched)
    if verbose:
        print(f"[2/4] Tagged {len(tagged)} kanji with JLPT/kana categories")
    return tagged


def add_keywords(entries: Iterable[dict], keyword_map: Dict[str, Dict[str, str]], verbose: bool) -> List[dict]:
    enriched: List[dict] = []
    for entry in entries:
        char = entry.get("kanji") or entry.get("char") or ""
        if not char:
            continue

        uniq_kw = (keyword_map.get(char, {}) or {}).get("uniq", "") or ""
        kana_reading = add_keywords_mod.get_kana_reading(char)
        if not uniq_kw and kana_reading:
            uniq_kw = kana_reading

        updated = dict(entry)
        updated["keyword"] = {"uniq": uniq_kw}
        enriched.append(updated)
    if verbose:
        print(f"[3/4] Attached keyword metadata to {len(enriched)} kanji")
    return enriched


# --- SQLite encoding --------------------------------------------------------
def pack_points(points: List[List[float]]) -> bytes:
    flat: List[float] = []
    for pt in points:
        if len(pt) >= 2:
            flat.extend([float(pt[0]), float(pt[1])])

    if len(flat) < FLOATS_PER_STROKE:
        flat.extend([0.0] * (FLOATS_PER_STROKE - len(flat)))
    else:
        flat = flat[:FLOATS_PER_STROKE]

    return struct.pack("<" + "f" * FLOATS_PER_STROKE, *flat)


def write_sqlite(entries: List[dict], out_path: Path, verbose: bool) -> None:
    if verbose:
        print(f"[4/4] Writing SQLite DB -> {out_path}")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        out_path.unlink()

    conn = sqlite3.connect(out_path)
    cur = conn.cursor()

    cur.executescript(
        """
        PRAGMA journal_mode = OFF;
        PRAGMA synchronous = OFF;
        CREATE TABLE kanji(
            id TEXT PRIMARY KEY,
            char TEXT NOT NULL,
            stroke_count INTEGER NOT NULL,
            keyword TEXT
        );
        CREATE TABLE kanji_tags(
            kanji_id TEXT NOT NULL,
            tag TEXT NOT NULL
        );
        CREATE TABLE strokes(
            kanji_id TEXT NOT NULL,
            stroke_index INTEGER NOT NULL,
            stroke_id TEXT,
            points BLOB NOT NULL,
            PRIMARY KEY(kanji_id, stroke_index)
        );
        CREATE INDEX idx_kanji_tags_tag ON kanji_tags(tag);
        CREATE INDEX idx_strokes_kanji ON strokes(kanji_id);
        """
    )

    kanji_rows = []
    tag_rows = []
    stroke_rows = []

    for entry in entries:
        kanji_id = entry.get("id") or ""
        char = entry.get("char") or ""
        strokes = entry.get("strokes") or []
        keyword = (entry.get("keyword") or {}).get("uniq") or None

        kanji_rows.append((kanji_id, char, len(strokes), keyword))

        for tag in entry.get("tags") or []:
            tag_rows.append((kanji_id, tag))

        for idx, stroke in enumerate(strokes):
            points = stroke.get("points") or []
            stroke_id = stroke.get("id")
            blob = pack_points(points)
            stroke_rows.append(
                (kanji_id, idx, stroke_id, sqlite3.Binary(blob))
            )

    cur.executemany(
        "INSERT INTO kanji(id, char, stroke_count, keyword) VALUES (?, ?, ?, ?)",
        kanji_rows,
    )
    cur.executemany(
        "INSERT INTO kanji_tags(kanji_id, tag) VALUES (?, ?)",
        tag_rows,
    )
    cur.executemany(
        "INSERT INTO strokes(kanji_id, stroke_index, stroke_id, points) VALUES (?, ?, ?, ?)",
        stroke_rows,
    )

    conn.commit()
    conn.close()
    if verbose:
        print(
            f"    ✓ Wrote {len(kanji_rows)} kanji, {len(tag_rows)} tags, {len(stroke_rows)} strokes"
        )


# --- CLI --------------------------------------------------------------------
def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate kanji.sqlite for Beat Kanji")
    parser.add_argument("--input", default="res/kanji.xml", help="KanjiVG XML path or directory")
    parser.add_argument("--jlpt", default="res/kanji_jlpt_only.json", help="JLPT lookup JSON")
    parser.add_argument("--keywords", default="res/kanji-keys.json", help="Keyword map JSON")
    parser.add_argument("--out", default="Beat Kanji/Resources/Data/kanji.sqlite", help="Output sqlite path")
    parser.add_argument("--samples", type=int, default=SAMPLES_PER_STROKE, help="Samples per stroke polyline (default 64)")
    parser.add_argument("--normalize-size", type=float, default=109.0, help="Normalization size for KanjiVG coordinates")
    parser.add_argument("--verbose", action="store_true", help="Print progress")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    input_path = Path(args.input)
    jlpt_lookup = load_jlpt_lookup(Path(args.jlpt))
    keyword_map = add_keywords_mod.load_keyword_map(Path(args.keywords))

    raw_entries = convert_kanjivg(
        input_path=input_path,
        samples=args.samples,
        normalize_size=args.normalize_size,
        verbose=args.verbose,
    )
    tagged_entries = annotate_tags(raw_entries, jlpt_lookup, verbose=args.verbose)
    enriched_entries = add_keywords(tagged_entries, keyword_map, verbose=args.verbose)
    write_sqlite(enriched_entries, Path(args.out), verbose=args.verbose)

    if args.verbose:
        print("Done.")


if __name__ == "__main__":
    main()
