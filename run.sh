#!/bin/bash
set -euo pipefail

# Load .env if present
if [ -f ".env" ]; then
    source .env
fi

CONFIGURATION=${CONFIGURATION:-Debug}
DERIVED_DATA_PATH=${DERIVED_DATA_PATH:-build/DerivedData}
APP_NAME=${APP_NAME:-"Beat Kanji"}

if [ -z "${UDID:-}" ]; then
    echo "error: UDID is not set. Please set UDID in your .env file." >&2
    echo "You can find your device UDID with: xcrun devicectl list devices" >&2
    exit 1
fi

APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphoneos/$APP_NAME.app"

if [[ ! -d "$APP" ]]; then
  echo "error: app bundle not found at $APP. Run build.sh first or check your paths." >&2
  exit 1
fi

xcrun devicectl device install app --device "$UDID" "$APP"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")

xcrun devicectl device process launch --console --terminate-existing \
  --device "$UDID" "$BUNDLE_ID"
