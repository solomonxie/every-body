#!/bin/sh
# Re-render the home page system tiles from the real 3D body (transparent PNGs).
# Usage: scripts/render_body/tiles.sh
set -e
cd "$(dirname "$0")/../.."
PY=${PY:-venv/bin/python}
[ -x "$PY" ] || PY=../../../venv/bin/python
ASSETS=Resources/Assets.xcassets
TMP=$(mktemp -d)

# id layers yaw focusY distance [crop-top]
tile() {
  BG="#FFFFFF" scripts/render_body/render.sh "$TMP/$1-w.png" "$2" "$3" "$4" "$5" >/dev/null
  BG="#000000" scripts/render_body/render.sh "$TMP/$1-b.png" "$2" "$3" "$4" "$5" >/dev/null
  "$PY" scripts/render_body/matte.py "$TMP/$1-w.png" "$TMP/$1-b.png" "$ASSETS/tile-$1.imageset/$(ls "$ASSETS/tile-$1.imageset" | grep png)" "${6:-0.02}"
}

tile skeletal skeletal 0.45 0.6 3.6
tile muscular muscular 0.45 0.6 3.6
tile circulatory circulatory 0.45 0.6 2.9
tile nervous nervous,skeletal 0.45 0.6 3.6
tile organs organs 0.3 0.5 3.4
tile digestive organs 0.3 0.1 2.7
