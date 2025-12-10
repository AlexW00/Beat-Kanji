#!/usr/bin/env bash
set -euo pipefail

# Utility script to regenerate the kanji dataset:
#   - Beat Kanji/Resources/Data/kanji.sqlite (final output for the app bundle)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Source files (in res/)
KANJI_XML="res/kanji.xml"

# Output files
DATA_DIR="Beat Kanji/Resources/Data"
KANJI_DB="${DATA_DIR}/kanji.sqlite"

echo "Generating ${KANJI_DB} from ${KANJI_XML}..."
python3 scripts/generate_kanji_db.py --input "${KANJI_XML}" --out "${KANJI_DB}" --verbose

echo "Done. Bundled payload: ${KANJI_DB}"

# Clean up legacy JSON artifacts
echo "Cleaning up legacy JSON artifacts..."
rm -f "${DATA_DIR}/kanji.json" "${DATA_DIR}/kanji.json.gz" \
      "res/kanji-extracted.json" "res/kanji-tagged.json" "res/kanji.json"

echo "Done."
