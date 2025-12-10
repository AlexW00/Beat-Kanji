#!/bin/bash

set -euo pipefail

# Set defaults if not provided
CONFIGURATION=${CONFIGURATION:-Debug}
SCHEME=${SCHEME:-"Beat Kanji"}
PROJECT=${PROJECT:-"Beat Kanji.xcodeproj"}
SIMULATOR_DEVICE=${SIMULATOR_DEVICE:-"iPhone 17"}
INCLUDE_SIMULATOR=${INCLUDE_SIMULATOR:-0}
KANJI_DB=${KANJI_DB:-"Beat Kanji/Resources/Data/kanji.sqlite"}
EXTERNAL_KANJI_DB=${EXTERNAL_KANJI_DB:-"../../Beat Kanji/Resources/Data/kanji.sqlite"}

# Run local configuration if present (e.g., signing setup)
if [[ -x "./configure.sh" ]]; then
    ./configure.sh
elif [[ -f "./configure.sh" ]]; then
    echo "configure.sh exists but is not executable; skipping"
fi

if [[ -f "$EXTERNAL_KANJI_DB" ]]; then
    echo "Found external kanji dataset at $EXTERNAL_KANJI_DB; copying into bundle"
    mkdir -p "$(dirname "$KANJI_DB")"
    cp "$EXTERNAL_KANJI_DB" "$KANJI_DB"
elif [[ ! -f "$KANJI_DB" ]]; then
    echo "Kanji dataset missing ($KANJI_DB); generating..."
    if [[ -x "./scripts/generate_kanji.sh" ]]; then
        ./scripts/generate_kanji.sh
    else
        bash ./scripts/generate_kanji.sh
    fi
fi

echo "Building Beat Kanji for device (iphoneos)..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath build/DerivedData \
    -destination "generic/platform=iOS" \
    build

case "$INCLUDE_SIMULATOR" in
    1|true|TRUE|yes|YES)
        echo "Building Beat Kanji for simulator ($SIMULATOR_DEVICE)..."
        xcodebuild -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -derivedDataPath build/DerivedData \
            -destination "platform=iOS Simulator,name=$SIMULATOR_DEVICE" \
            build
            ;;
esac
