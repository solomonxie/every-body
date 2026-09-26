#!/bin/sh
# Render the reflex charts on the Mac with the app's own ChartCanvas.
# Usage: scripts/render_charts/render.sh [outDir] [zoneId]
set -e
cd "$(dirname "$0")/../.."
BIN=build/render-charts
mkdir -p build
swiftc -O -parse-as-library -o "$BIN" \
  scripts/render_charts/Shim.swift scripts/render_charts/main.swift \
  Sources/Charts/ChartCanvas.swift Sources/Charts/SVGPath.swift \
  Sources/Data/Models.swift Sources/Data/Catalog.swift 2>&1 | grep -E "error" >&2 && rm -f "$BIN" || true
BODY_ATLAS_DATA=Resources/Data "$BIN" "${1:-build/charts}" "$2"
