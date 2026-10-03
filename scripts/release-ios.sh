#!/bin/sh
# Archive a Release build and upload it to App Store Connect in one go.
# Needs: Xcode → Settings → Accounts signed in to the developer Apple ID, and
# DEVELOPMENT_TEAM + IOS_BUNDLE_ID in the gitignored .env.local (see .env.local.example).
#
# Build number is a timestamp so every upload is higher than the last;
# the user-visible version is MARKETING_VERSION in project.yml.
# One binary serves every storefront, so STORE stays us unless overridden.
#
# Usage: scripts/release-ios.sh [build-number]
set -e
cd "$(dirname "$0")/.."

[ -f .env.local ] || { echo "Missing .env.local — cp .env.local.example .env.local and fill it in"; exit 1; }
. ./.env.local
: "${DEVELOPMENT_TEAM:?set DEVELOPMENT_TEAM (Apple Developer Team ID) in .env.local}"
: "${IOS_BUNDLE_ID:?set IOS_BUNDLE_ID in .env.local}"

SCHEME=EveryBody
BUILD=${1:-$(date +%Y%m%d%H%M)}
OUT=/tmp/everybody-release
ARCHIVE=$OUT/$SCHEME-$BUILD.xcarchive

xcodegen generate --quiet
xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" PRODUCT_BUNDLE_IDENTIFIER="$IOS_BUNDLE_ID" \
  STORE="${STORE:-us}" CURRENT_PROJECT_VERSION="$BUILD" archive

xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$OUT/export" -allowProvisioningUpdates

echo "Uploaded build $BUILD. Processing in App Store Connect takes 15–60 min."
