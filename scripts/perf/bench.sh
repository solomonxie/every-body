#!/bin/sh
# CPU timings of the 3D hot paths on the Mac (figure load, joint drag, posture scrub, CPR frame and touch) and checksums.
# Usage: scripts/perf/bench.sh [load,drag,posture,cpr]   Env: MODELS=path/to/Resources/Models
set -e
cd "$(dirname "$0")/../.."
BIN=build/perf-bench
mkdir -p build
SRC="scripts/render_body/Shim.swift scripts/perf/bench.swift \
  Sources/Body/BodyScene.swift Sources/Body/Meshes.swift Sources/Body/Textures.swift Sources/Body/ModelLibrary.swift Sources/Body/Figure.swift Sources/Body/InternalModels.swift \
  Sources/Data/Models.swift Sources/Data/Catalog.swift Sources/Data/Profile.swift \
  Sources/Posture/PostureModel.swift Sources/Posture/PostureScene.swift \
  Sources/Trainer/CPRTrainerScene.swift Sources/Trainer/SkinDeformer.swift Sources/Trainer/CPRCoach.swift"
if [ ! -x "$BIN" ] || [ -n "$(find $SRC -newer "$BIN" 2>/dev/null)" ]; then
  nice -n 10 swiftc -O -parse-as-library -o "$BIN" $SRC 2>&1 | grep -E "error" >&2 && rm -f "$BIN" || true
fi
# (hash order changes some bends per launch: fixed for comparable checksums)
SWIFT_DETERMINISTIC_HASHING=1 BODY_ATLAS_DATA=Resources/Data BODY_ATLAS_MODELS="${MODELS:-Resources/Models}" nice -n 10 "$BIN" "$@"
