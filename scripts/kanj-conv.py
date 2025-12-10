
#!/usr/bin/env python3
"""
KanjiVG -> polyline converter (with "char" field).

Reads KanjiVG XML/SVG files and outputs stroke polylines as JSON.
Each <path ... d="..."> becomes one stroke with a list of sampled points.
Also tries to derive the actual kanji character and stores it as "char".

Dependency (recommended for correct SVG Bézier sampling):
    pip install svgpathtools numpy

This module is imported by generate_kanji_db.py to feed the SQLite pipeline.
CLI usage is retained for debugging (JSON output) but the app now ships kanji.sqlite.

Options:
  --samples N        points per stroke (default 64)
  --normalize        divide coordinates by 109.0 to get 0..1 space
  --size S           normalization base (default 109.0)
  --pretty           pretty-print JSON
"""

import argparse
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
from svgpathtools import parse_path


KVG_NS = {"kvg": "http://kanjivg.tagaini.net"}  # KanjiVG namespace
HEX_RE = re.compile(r"([0-9a-fA-F]{4,6})")


def sample_svg_path(d: str, samples: int) -> list[list[float]]:
    """
    Sample an SVG path `d` into a polyline with `samples` points.
    Uses svgpathtools to handle M/L/C/Q/A/Z etc.
    """
    p = parse_path(d)
    if len(p) == 0:
        return []
    ts = np.linspace(0.0, 1.0, samples)
    pts = []
    for t in ts:
        c = p.point(t)  # complex x + yj
        pts.append([float(c.real), float(c.imag)])
    return pts


def normalize_points(points: list[list[float]], size: float) -> list[list[float]]:
    if size <= 0:
        return points
    return [[x / size, y / size] for x, y in points]


def hex_to_char(hex_str: str) -> str:
    try:
        return chr(int(hex_str, 16))
    except Exception:
        return ""


def char_from_element(kn: ET.Element) -> str:
    """
    Try to read the literal character from kvg:element on the first group.
    In KanjiVG data, the outermost g usually has the actual kanji.
    """
    g = kn.find(".//g[@kvg:element]", KVG_NS)
    if g is None:
        return ""
    val = g.attrib.get(f"{{{KVG_NS['kvg']}}}element", "")
    return val if len(val) == 1 else ""


def char_from_kanji_id(kanji_id: str) -> str:
    """
    Derive the character from id, e.g.:
      kvg:kanji_04f55 -> U+4F55 -> 何
    """
    m = HEX_RE.search(kanji_id)
    return hex_to_char(m.group(1)) if m else ""


def char_from_filename(filename: str) -> str:
    """
    Derive the character from filename, e.g.:
      u04f55.svg -> U+4F55 -> 何
      04f55.svg  -> same
    """
    stem = Path(filename).stem
    if stem.startswith("u") and len(stem) > 1:
        stem = stem[1:]
    m = HEX_RE.search(stem)
    return hex_to_char(m.group(1)) if m else ""


def extract_kanji_from_tree(
    tree: ET.ElementTree,
    samples: int,
    do_normalize: bool,
    size: float,
    source_filename: str = ""
):
    root = tree.getroot()
    kanji_nodes = root.findall(".//kanji")
    results = []

    for kn in kanji_nodes:
        kanji_id = kn.attrib.get("id", "")

        # Determine actual character for "char"
        ch = char_from_element(kn)
        if not ch:
            ch = char_from_kanji_id(kanji_id)
        if not ch and source_filename:
            ch = char_from_filename(source_filename)

        # Collect strokes
        stroke_paths = kn.findall(".//path")
        strokes_json = []
        for path_node in stroke_paths:
            d = path_node.attrib.get("d")
            if not d:
                continue
            stroke_id = path_node.attrib.get("id", "")
            points = sample_svg_path(d, samples)
            if do_normalize:
                points = normalize_points(points, size)
            strokes_json.append({
                "id": stroke_id,
                "points": points
            })

        results.append({
            "id": kanji_id,
            "char": ch,
            "strokes": strokes_json
        })

    return results


def load_xml(path: str) -> ET.ElementTree:
    return ET.parse(path)


def collect_files(input_path: str) -> list[str]:
    """
    If input is a directory, collect *.svg, *.xml.
    If input is a file, return [file].
    """
    if os.path.isdir(input_path):
        files = []
        for name in os.listdir(input_path):
            if name.lower().endswith((".svg", ".xml")):
                files.append(os.path.join(input_path, name))
        files.sort()
        return files
    return [input_path]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="KanjiVG XML file or directory of per-kanji files")
    ap.add_argument("--out", required=True, help="Output json file (single) or directory (--per-kanji)")
    ap.add_argument("--per-kanji", action="store_true",
                    help="Write one JSON per kanji into --out directory")
    ap.add_argument("--samples", type=int, default=64, help="Samples per stroke polyline")
    ap.add_argument("--normalize", action="store_true",
                    help="Normalize coordinates to 0..1 by dividing by --size (default 109)")
    ap.add_argument("--size", type=float, default=109.0, help="Normalization base size for KanjiVG coords")
    ap.add_argument("--pretty", action="store_true", help="Pretty print JSON")
    args = ap.parse_args()

    files = collect_files(args.input)
    all_kanji = []

    for f in files:
        try:
            tree = load_xml(f)
        except Exception as e:
            print(f"Failed to parse {f}: {e}", file=sys.stderr)
            continue

        kanji_list = extract_kanji_from_tree(
            tree,
            samples=args.samples,
            do_normalize=args.normalize,
            size=args.size,
            source_filename=f
        )

        if args.per_kanji:
            os.makedirs(args.out, exist_ok=True)
            for k in kanji_list:
                # Use char hex filename when possible
                if k["char"]:
                    tail = f"u{ord(k['char']):04x}"
                else:
                    tail = k["id"].split("_")[-1] if "_" in k["id"] else (k["id"] or "kanji")
                out_path = os.path.join(args.out, f"{tail}.json")
                with open(out_path, "w", encoding="utf-8") as w:
                    json.dump(k, w, ensure_ascii=False, indent=2 if args.pretty else None)
        else:
            all_kanji.extend(kanji_list)

    if not args.per_kanji:
        out_dir = os.path.dirname(args.out)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as w:
            json.dump(all_kanji, w, ensure_ascii=False, indent=2 if args.pretty else None)


if __name__ == "__main__":
    main()
