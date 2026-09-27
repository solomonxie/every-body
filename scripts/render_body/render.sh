#!/bin/sh
# Render the real 3D body on the Mac (RealityKit), no phone needed.
# Usage: scripts/render_body/render.sh out.png "skin,organs" [yaw] [focusY distance] [male|female] [infant|child|adult|senior]
# Env: HERITAGE=black, UNDERWEAR=0, PREGNANT=1, POINTS=acupuncture, FOCUS=acu-li11, PANX, PITCH, JOINT=elbow-l:90, BG
set -e
cd "$(dirname "$0")/../.."
BIN=build/render-body
mkdir -p build
SRC="scripts/render_body/Shim.swift scripts/render_body/main.swift \
  Sources/Body/BodyScene.swift Sources/Body/Meshes.swift Sources/Body/Textures.swift Sources/Body/ModelLibrary.swift Sources/Body/Figure.swift \
  Sources/Data/Models.swift Sources/Data/Catalog.swift Sources/Data/Profile.swift"
# rebuild only when a source changed
if [ ! -x "$BIN" ] || [ -n "$(find $SRC -newer "$BIN" 2>/dev/null)" ]; then
  swiftc -O -parse-as-library -o "$BIN" $SRC 2>&1 | grep -E "error" >&2 && rm -f "$BIN" || true
fi
# REAL_MODELS=0 renders the generated skeleton and skin instead of Resources/Models
BODY_ATLAS_DATA=Resources/Data BODY_ATLAS_MODELS=Resources/Models "$BIN" "$@"
