#!/bin/sh
# Built model binaries live outside git: a zip on the GitHub release "models", pinned by Resources/Models/assets.sha256.
# Usage: scripts/models/assets.sh push|pull|check
#   push   hash the local binaries into the manifest and upload them (commit the manifest after)
#   pull   download the zip and unpack it, then check it matches the manifest
#   check  fail unless the local binaries match the manifest
set -e
cd "$(dirname "$0")/../.."
TAG=models
ZIP=build/models.zip
MANIFEST=Resources/Models/assets.sha256

files() { find Resources/Models -type f \( -name '*.bin' -o -name '*.usdz' -o -name '*.jpg' -o -name '*.png' \) | LC_ALL=C sort; }

case "$1" in
push)
  files | xargs shasum -a 256 > "$MANIFEST"
  mkdir -p build && rm -f "$ZIP"
  files | zip -q -X "$ZIP" -@
  gh release view "$TAG" >/dev/null 2>&1 || gh release create "$TAG" --title "Model binaries" --notes "Built by scripts/models/build.sh; fetched by scripts/models/assets.sh pull."
  gh release upload "$TAG" "$ZIP" --clobber
  echo "uploaded $(files | wc -l | tr -d ' ') files; commit $MANIFEST"
  ;;
pull)
  mkdir -p build && rm -f "$ZIP"
  gh release download "$TAG" -p models.zip -O "$ZIP"
  unzip -q -o "$ZIP"
  "$0" check
  ;;
check)
  [ -f "$MANIFEST" ] || { echo "no $MANIFEST"; exit 1; }
  shasum -a 256 -c --quiet "$MANIFEST" || { echo "models differ from $MANIFEST: run scripts/models/assets.sh pull (or push after a rebuild)"; exit 1; }
  ;;
*)
  echo "usage: $0 push|pull|check"; exit 2 ;;
esac
