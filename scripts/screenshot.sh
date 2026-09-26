#!/bin/sh
# Open a screen on the paired iPhone and save a screenshot.
# Usage: scripts/screenshot.sh viewer/skeletal /tmp/out.png [wait-seconds]
set -e
. ./.env.local
UDID=$(xcrun devicectl list devices 2>/dev/null | grep physical | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}' | head -1)
xcrun devicectl device process launch --terminate-existing --device "$UDID" --payload-url "bodyatlas://$1" "$IOS_BUNDLE_ID" >/dev/null
sleep "${3:-5}"
xcrun devicectl device capture screenshot --device "$UDID" --destination "$2" >/dev/null
