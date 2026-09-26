#!/bin/sh
# Render app screens on the Mac (light/dark × EN/中文), no phone needed.
# Usage: scripts/render_ui/render.sh /tmp/ui [home|suggest|results|nomatch|info|player…]
set -e
cd "$(dirname "$0")/../.."
BIN=build/render-ui
mkdir -p build
swiftc -O -parse-as-library -o "$BIN" \
  scripts/render_ui/Shim.swift scripts/render_ui/main.swift \
  Sources/Common/Theme.swift Sources/Common/Pill.swift Sources/Common/Settings.swift Sources/Common/ProfileMenu.swift \
  Sources/Screens/*.swift Sources/Viewer/ViewerPanels.swift Sources/Illustrations/IllustrationsSection.swift Sources/Illustrations/Player.swift \
  Sources/Illustrations/Scenario.swift Sources/Illustrations/Sketch.swift Sources/Illustrations/Illustrations.swift \
  Sources/Illustrations/Figures.swift Sources/Illustrations/Scenes/*.swift Sources/Charts/SVGPath.swift \
  Sources/App/Route.swift Sources/Data/Models.swift Sources/Data/Catalog.swift Sources/Data/Profile.swift Sources/Data/Cautions.swift \
  2>&1 | grep -E "error" >&2 && rm -f "$BIN" || true
BODY_ATLAS_DATA=Resources/Data "$BIN" "$@"
