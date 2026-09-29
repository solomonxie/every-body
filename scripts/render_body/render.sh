#!/bin/sh
# Render the real 3D body on the Mac (RealityKit), no phone needed.
# Usage: scripts/render_body/render.sh out.png "skin,organs" [yaw] [focusY distance] [male|female] [infant|child|adult|senior]
# Env: HERITAGE=black, UNDERWEAR=0, PREGNANT=1, CHEST=small|medium|large, HIPS=…, POINTS=acupuncture, FOCUS=acu-li11, PANX, PITCH, JOINT=elbow-l:90, BG
# Posture scenes: POSTURE=sitting [BLEND=0..1] [SIZE=430x400] [VIEW=side|back|front] [SOLID=1] [YAW PITCH DIST FOCUSY] render.sh out.png - - - - [female]
# CPR trainer: TRAINER=check|find-miss|find|compress|compress-down|tilt|breath|bump|aed|aed-drag|aed-placed (+ GLASS=1, AZ, EL, ZOOM)
#   e.g. TRAINER=compress-down GLASS=1 scripts/render_body/render.sh /tmp/t.png skin 0 - - female adult
set -e
cd "$(dirname "$0")/../.."
BIN=build/render-body
mkdir -p build
SRC="scripts/render_body/Shim.swift scripts/render_body/main.swift \
  Sources/Body/BodyScene.swift Sources/Body/Meshes.swift Sources/Body/Textures.swift Sources/Body/ModelLibrary.swift Sources/Body/Figure.swift Sources/Body/InternalModels.swift \
  Sources/Data/Models.swift Sources/Data/Catalog.swift Sources/Data/Profile.swift \
  Sources/Posture/PostureModel.swift Sources/Posture/PostureScene.swift \
  Sources/Trainer/CPRTrainerScene.swift Sources/Trainer/SkinDeformer.swift Sources/Trainer/CPRCoach.swift"
# rebuild only when a source changed
if [ ! -x "$BIN" ] || [ -n "$(find $SRC -newer "$BIN" 2>/dev/null)" ]; then
  swiftc -O -parse-as-library -o "$BIN" $SRC 2>&1 | grep -E "error" >&2 && rm -f "$BIN" || true
fi
# REAL_MODELS=0 renders the generated skeleton and skin instead of Resources/Models
BODY_ATLAS_DATA=Resources/Data BODY_ATLAS_MODELS=Resources/Models "$BIN" "$@"
