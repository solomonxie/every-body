#!/bin/sh
# Render illustration steps to PNG on the Mac (no phone needed).
# Usage: [ZH=1] [PROFILE=infant|child|adult|senior|pregnant] scripts/render_scenes/render.sh /tmp/scenes [scenario-id…]
set -e
cd "$(dirname "$0")/../.."
BIN=build/render-scenes
mkdir -p build
swiftc -O -parse-as-library -o "$BIN" \
  scripts/render_scenes/Shim.swift scripts/render_scenes/main.swift \
  Sources/Illustrations/Scenario.swift Sources/Illustrations/Sketch.swift Sources/Illustrations/Illustrations.swift \
  Sources/Illustrations/Figures.swift Sources/Data/Profile.swift Sources/Illustrations/Scenes/*.swift Sources/Charts/SVGPath.swift 2>&1 | grep -E "error" || true
"$BIN" "$@"
