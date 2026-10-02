#!/bin/sh
# Build and install onto the paired iPhone — never a simulator.
# Usage: scripts/install-ios-device.sh [device-udid]   (defaults to the only paired device)
# Needs DEVELOPMENT_TEAM and IOS_BUNDLE_ID in the gitignored .env.local.
# STORE=cn bakes the App Store region into Info.plist (AppStoreRegion); default us (Canada/US).
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
STORE=${STORE:-us}

xcodegen generate --quiet
xcodebuild -project EveryBody.xcodeproj -scheme EveryBody \
  -configuration "$CONFIG" -destination "id=$UDID" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" PRODUCT_BUNDLE_IDENTIFIER="$IOS_BUNDLE_ID" STORE="$STORE" \
  -derivedDataPath build/dd build | grep -E "error:|warning: .*Sources|BUILD" || true

xcrun devicectl device install app --device "$UDID" \
  "build/dd/Build/Products/$CONFIG-iphoneos/EveryBody.app"
