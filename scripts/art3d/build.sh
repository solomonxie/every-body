#!/bin/sh
# Render the scene pictures (Blender headless, MPFB humans) and pack them into Resources/Illustrations.
# Usage: scripts/art3d/build.sh [scene[:shot] …]   (default: every scene; see render.py)
# Tools as for scripts/models/build.sh: $EVERYBODY_TOOLS (default ./tools) with Blender.app and blender-user (MPFB2 + assets).
set -e
cd "$(dirname "$0")/../.."
TOOLS=${EVERYBODY_TOOLS:-$PWD/tools}
BLENDER_USER_RESOURCES="$TOOLS/blender-user" "$TOOLS/Blender.app/Contents/MacOS/Blender" -b -P scripts/art3d/render.py -- "$@" style=ink \
  2>&1 | grep -E "^RENDERED|Error|Traceback" || true
${PYTHON:-venv/bin/python} scripts/art3d/pack.py ink
