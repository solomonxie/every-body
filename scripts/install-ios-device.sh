#!/bin/sh
# Build a Release (JS bundled, no Metro needed) and install onto the paired iPhone — never a simulator.
# Usage: scripts/install-ios-device.sh [device-udid]   (defaults to the only paired device)
# Needs DEVELOPMENT_TEAM and IOS_BUNDLE_ID in the gitignored .env.local.
set -e
cd "$(dirname "$0")/.."

[ -f .env.local ] && . ./.env.local

UDID=${1:-$(xcrun devicectl list devices 2>/dev/null | grep physical \
  | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}' \
  | head -1)}
: "${UDID:?no paired iPhone found — plug one in and trust this Mac}"
: "${DEVELOPMENT_TEAM:?set DEVELOPMENT_TEAM (Apple Developer Team ID) in .env.local}"
: "${IOS_BUNDLE_ID:?set IOS_BUNDLE_ID in .env.local}"

CONFIG=${CONFIG:-Release}

[ -d ios ] || CI=1 npx expo prebuild -p ios

xcodebuild -workspace ios/BodyAtlas.xcworkspace -scheme BodyAtlas \
  -configuration "$CONFIG" -destination "id=$UDID" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
  -derivedDataPath build/dd build | tail -20

xcrun devicectl device install app --device "$UDID" \
  "build/dd/Build/Products/$CONFIG-iphoneos/BodyAtlas.app"
