"""Shared kana character sets for filtering/tagging.

We intentionally keep only the modern, full-size hiragana/katakana used in
everyday writing so we can drop small/archaic forms (e.g. ぁ, ゑ, ヰ, ヱ, ヮ).
"""

from __future__ import annotations

# Modern hiragana (gojūon + dakuten/handakuten, optionally ゔ)
MODERN_HIRAGANA: set[str] = {
    "あ", "い", "う", "え", "お",
    "か", "き", "く", "け", "こ",
    "さ", "し", "す", "せ", "そ",
    "た", "ち", "つ", "て", "と",
    "な", "に", "ぬ", "ね", "の",
    "は", "ひ", "ふ", "へ", "ほ",
    "ま", "み", "む", "め", "も",
    "や", "ゆ", "よ",
    "ら", "り", "る", "れ", "ろ",
    "わ", "を", "ん",
    # Dakuten (voiced)
    "が", "ぎ", "ぐ", "げ", "ご",
    "ざ", "じ", "ず", "ぜ", "ぞ",
    "だ", "ぢ", "づ", "で", "ど",
    "ば", "び", "ぶ", "べ", "ぼ",
    # Handakuten (semi-voiced)
    "ぱ", "ぴ", "ぷ", "ぺ", "ぽ",
    # Extended modern kana
    "ゔ",
}


# Modern katakana (full size + dakuten/handakuten, optionally ヴ)
MODERN_KATAKANA: set[str] = {
    "ア", "イ", "ウ", "エ", "オ",
    "カ", "キ", "ク", "ケ", "コ",
    "サ", "シ", "ス", "セ", "ソ",
    "タ", "チ", "ツ", "テ", "ト",
    "ナ", "ニ", "ヌ", "ネ", "ノ",
    "ハ", "ヒ", "フ", "ヘ", "ホ",
    "マ", "ミ", "ム", "メ", "モ",
    "ヤ", "ユ", "ヨ",
    "ラ", "リ", "ル", "レ", "ロ",
    "ワ", "ヲ", "ン",
    # Dakuten (voiced)
    "ガ", "ギ", "グ", "ゲ", "ゴ",
    "ザ", "ジ", "ズ", "ゼ", "ゾ",
    "ダ", "ヂ", "ヅ", "デ", "ド",
    "バ", "ビ", "ブ", "ベ", "ボ",
    # Handakuten (semi-voiced)
    "パ", "ピ", "プ", "ペ", "ポ",
    # Extended modern kana
    "ヴ",
}


def is_modern_hiragana(ch: str) -> bool:
    """Return True when the character is a modern, full-size hiragana."""

    return ch in MODERN_HIRAGANA


def is_modern_katakana(ch: str) -> bool:
    """Return True when the character is a modern, full-size katakana."""

    return ch in MODERN_KATAKANA

