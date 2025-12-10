#!/usr/bin/env python3
"""
Annotate kanji entries with JLPT/kana tags.

This module is imported by generate_kanji_db.py; CLI JSON output is kept for
debugging or one-off tooling.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Iterable

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from kana_sets import is_modern_hiragana, is_modern_katakana


def tags_for_entry(
    char: str, entry: dict[str, Any], jlpt_lookup: dict[str, int]
) -> list[str]:
    tags: list[str] = []

    jlpt = jlpt_lookup.get(char)
    if isinstance(jlpt, int) and 1 <= jlpt <= 5:
        tags.append(f"n{jlpt}")

    if len(char) == 1:
        if is_modern_hiragana(char):
            tags.append("hiragana")
        elif is_modern_katakana(char):
            tags.append("katakana")

    return tags


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        default="res/kanji-extracted.json",
        help="Input JSON path containing kanji entries (dict or list)",
    )
    parser.add_argument(
        "--reference",
        default="res/kanji_jlpt_only.json",
        help="Reference JSON path providing JLPT info",
    )
    parser.add_argument(
        "--out",
        required=True,
        help="Output JSON path for annotated entries",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print output JSON",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    with Path(args.reference).open("r", encoding="utf-8") as f:
        jlpt_data: dict[str, dict[str, Any]] = json.load(f)
    jlpt_lookup = {
        k: v.get("jlpt")
        for k, v in jlpt_data.items()
        if isinstance(v, dict) and "jlpt" in v
    }

    with input_path.open("r", encoding="utf-8") as f:
        raw_data: Any = json.load(f)

    def annotate_entries(
        items: Iterable[tuple[str, dict[str, Any]]],
    ) -> dict[str, dict[str, Any]]:
        annotated: dict[str, dict[str, Any]] = {}
        for key, entry in items:
            if not isinstance(entry, dict):
                continue
            char = entry.get("kanji") or entry.get("char") or key
            if not isinstance(char, str) or not char:
                continue
            tags = tags_for_entry(char, entry, jlpt_lookup)
            if not tags:
                continue
            enriched = dict(entry)
            enriched["tags"] = tags
            annotated[key] = enriched
        return annotated

    if isinstance(raw_data, dict):
        annotated = annotate_entries(raw_data.items())
    elif isinstance(raw_data, list):
        annotated_dict = annotate_entries(
            ((entry.get("kanji") or entry.get("char") or str(idx)), entry)
            for idx, entry in enumerate(raw_data)
        )
        # Preserve order for list inputs by filtering with the annotated keys
        annotated = [
            annotated_dict[key]
            for idx, entry in enumerate(raw_data)
            if (key := (entry.get("kanji") or entry.get("char") or str(idx)))
            in annotated_dict
        ]
    else:
        raise TypeError("Input JSON must be an object or array")

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    indent = 2 if args.pretty else None
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(annotated, f, ensure_ascii=False, indent=indent)


if __name__ == "__main__":
    main()
