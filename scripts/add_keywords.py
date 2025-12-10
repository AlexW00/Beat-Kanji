#!/usr/bin/env python3
"""
Merge keyword metadata onto generated kanji entries.

Used by generate_kanji_db.py; CLI JSON output is retained for debugging/tools.
Also adds romaji readings for hiragana/katakana characters.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, Optional, Tuple

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from kana_sets import is_modern_hiragana, is_modern_katakana

# Hiragana to romaji mapping
HIRAGANA_TO_ROMAJI = {
    "あ": "a",
    "い": "i",
    "う": "u",
    "え": "e",
    "お": "o",
    "か": "ka",
    "き": "ki",
    "く": "ku",
    "け": "ke",
    "こ": "ko",
    "さ": "sa",
    "し": "shi",
    "す": "su",
    "せ": "se",
    "そ": "so",
    "た": "ta",
    "ち": "chi",
    "つ": "tsu",
    "て": "te",
    "と": "to",
    "な": "na",
    "に": "ni",
    "ぬ": "nu",
    "ね": "ne",
    "の": "no",
    "は": "ha",
    "ひ": "hi",
    "ふ": "fu",
    "へ": "he",
    "ほ": "ho",
    "ま": "ma",
    "み": "mi",
    "む": "mu",
    "め": "me",
    "も": "mo",
    "や": "ya",
    "ゆ": "yu",
    "よ": "yo",
    "ら": "ra",
    "り": "ri",
    "る": "ru",
    "れ": "re",
    "ろ": "ro",
    "わ": "wa",
    "を": "wo",
    "ん": "n",
    # Dakuten (voiced)
    "が": "ga",
    "ぎ": "gi",
    "ぐ": "gu",
    "げ": "ge",
    "ご": "go",
    "ざ": "za",
    "じ": "ji",
    "ず": "zu",
    "ぜ": "ze",
    "ぞ": "zo",
    "だ": "da",
    "ぢ": "di",
    "づ": "du",
    "で": "de",
    "ど": "do",
    "ば": "ba",
    "び": "bi",
    "ぶ": "bu",
    "べ": "be",
    "ぼ": "bo",
    # Handakuten (semi-voiced)
    "ぱ": "pa",
    "ぴ": "pi",
    "ぷ": "pu",
    "ぺ": "pe",
    "ぽ": "po",
    # Small kana
    "ぁ": "a",
    "ぃ": "i",
    "ぅ": "u",
    "ぇ": "e",
    "ぉ": "o",
    "ゃ": "ya",
    "ゅ": "yu",
    "ょ": "yo",
    "っ": "tsu",
    "ゎ": "wa",
    # Additional small kana
    "ゕ": "ka",
    "ゖ": "ke",
}

# Katakana to romaji mapping
KATAKANA_TO_ROMAJI = {
    "ア": "a",
    "イ": "i",
    "ウ": "u",
    "エ": "e",
    "オ": "o",
    "カ": "ka",
    "キ": "ki",
    "ク": "ku",
    "ケ": "ke",
    "コ": "ko",
    "サ": "sa",
    "シ": "shi",
    "ス": "su",
    "セ": "se",
    "ソ": "so",
    "タ": "ta",
    "チ": "chi",
    "ツ": "tsu",
    "テ": "te",
    "ト": "to",
    "ナ": "na",
    "ニ": "ni",
    "ヌ": "nu",
    "ネ": "ne",
    "ノ": "no",
    "ハ": "ha",
    "ヒ": "hi",
    "フ": "fu",
    "ヘ": "he",
    "ホ": "ho",
    "マ": "ma",
    "ミ": "mi",
    "ム": "mu",
    "メ": "me",
    "モ": "mo",
    "ヤ": "ya",
    "ユ": "yu",
    "ヨ": "yo",
    "ラ": "ra",
    "リ": "ri",
    "ル": "ru",
    "レ": "re",
    "ロ": "ro",
    "ワ": "wa",
    "ヲ": "wo",
    "ン": "n",
    # Dakuten (voiced)
    "ガ": "ga",
    "ギ": "gi",
    "グ": "gu",
    "ゲ": "ge",
    "ゴ": "go",
    "ザ": "za",
    "ジ": "ji",
    "ズ": "zu",
    "ゼ": "ze",
    "ゾ": "zo",
    "ダ": "da",
    "ヂ": "di",
    "ヅ": "du",
    "デ": "de",
    "ド": "do",
    "バ": "ba",
    "ビ": "bi",
    "ブ": "bu",
    "ベ": "be",
    "ボ": "bo",
    # Handakuten (semi-voiced)
    "パ": "pa",
    "ピ": "pi",
    "プ": "pu",
    "ペ": "pe",
    "ポ": "po",
    # Small kana
    "ァ": "a",
    "ィ": "i",
    "ゥ": "u",
    "ェ": "e",
    "ォ": "o",
    "ャ": "ya",
    "ュ": "yu",
    "ョ": "yo",
    "ッ": "tsu",
    "ヮ": "wa",
    # Additional katakana
    "ヴ": "vu",
    "ヵ": "ka",
    "ヶ": "ke",
    # Extended katakana for foreign sounds
    "ヷ": "va",
    "ヸ": "vi",
    "ヹ": "ve",
    "ヺ": "vo",
}


def get_kana_reading(char: str) -> Optional[str]:
    """Get the romaji reading for a hiragana or katakana character."""
    if not (is_modern_hiragana(char) or is_modern_katakana(char)):
        return None

    if char in HIRAGANA_TO_ROMAJI:
        return HIRAGANA_TO_ROMAJI[char]
    if char in KATAKANA_TO_ROMAJI:
        return KATAKANA_TO_ROMAJI[char]
    return None


def load_keyword_map(json_path: Path) -> Dict[str, Dict[str, str]]:
    """Load keyword data from kanji-keys.json file."""
    keyword_map: Dict[str, Dict[str, str]] = {}
    with json_path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    for kanji, entry in data.items():
        if not kanji:
            continue
        keyword_map[kanji] = {
            "uniq": (entry.get("uniq") or "").strip(),
        }
    return keyword_map


def add_keywords_to_entries(
    items: Iterable[Tuple[str, Dict[str, Any]]],
    keyword_map: Dict[str, Dict[str, str]],
) -> Dict[str, Dict[str, Any]]:
    enriched: Dict[str, Dict[str, Any]] = {}
    for key, entry in items:
        if not isinstance(entry, dict):
            continue
        char = entry.get("kanji") or entry.get("char") or key
        if not isinstance(char, str) or not char:
            continue

        keywords = keyword_map.get(char, {})
        uniq_kw = keywords.get("uniq", "")

        # Check if this is a kana character and get its reading
        kana_reading = get_kana_reading(char)
        if kana_reading:
            # Use romaji reading for meaning fallbacks
            uniq_kw = uniq_kw or kana_reading

        updated = dict(entry)

        # Always add keyword object (even if empty) so the Swift model can parse it
        updated["keyword"] = {"uniq": uniq_kw}

        enriched[key] = updated
    return enriched


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        default="res/kanji-tagged.json",
        help="Input JSON path containing kanji entries (dict or list)",
    )
    parser.add_argument(
        "--keywords",
        default="res/kanji-keys.json",
        help="JSON file with kanji keys and uniq meanings",
    )
    parser.add_argument(
        "--out",
        required=True,
        help="Output JSON path for keyword-enriched entries",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print output JSON",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    keyword_map = load_keyword_map(Path(args.keywords))

    with input_path.open("r", encoding="utf-8") as f:
        raw_data: Any = json.load(f)

    if isinstance(raw_data, dict):
        enriched = add_keywords_to_entries(raw_data.items(), keyword_map)
    elif isinstance(raw_data, list):
        enriched_dict = add_keywords_to_entries(
            (
                ((entry.get("kanji") or entry.get("char") or str(idx)), entry)
                for idx, entry in enumerate(raw_data)
            ),
            keyword_map,
        )
        enriched = [
            enriched_dict[key]
            for idx, entry in enumerate(raw_data)
            if (key := (entry.get("kanji") or entry.get("char") or str(idx)))
            in enriched_dict
        ]
    else:
        raise TypeError("Input JSON must be an object or array")

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    indent = 2 if args.pretty else None
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(enriched, f, ensure_ascii=False, indent=indent)


if __name__ == "__main__":
    main()
