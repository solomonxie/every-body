#!/bin/sh
# Rebuild Resources/Models from the raw downloads (sources and licences: LICENSES/THIRD_PARTY.md).
# Usage: scripts/models/build.sh [skeleton|fit [group]|pack|report]   (default: everything)
# Tools live outside git in $EVERYBODY_TOOLS (default ./tools):
#   Blender.app            official macOS arm64 build (4.5 LTS), copied out of the .dmg
#   downloads/Z-Anatomy/   Startup.blend from github.com/Z-Anatomy/Models-of-human-anatomy (Z-Anatomy.zip)
#   blender-user/          Blender user dir with the MPFB2 extension + makehuman_system_assets_cc0 in
#                          extensions/.user/user_default/mpfb/data
set -e
cd "$(dirname "$0")/../.."
TOOLS=${EVERYBODY_TOOLS:-$PWD/tools}
export EVERYBODY_TOOLS="$TOOLS"
BLENDER="$TOOLS/Blender.app/Contents/MacOS/Blender"
PY=${PYTHON:-venv/bin/python}
export BLENDER_USER_RESOURCES="$TOOLS/blender-user"
step=${1:-all}
if [ "$step" = all ] || [ "$step" = skeleton ]; then
  "$BLENDER" -b "$TOOLS/downloads/Z-Anatomy/Startup.blend" -P scripts/models/build_models.py -- skeleton 2>&1 | grep -E "^(SKELETON|SKIN)|Error|error:" || true
fi
# skin figures: MPFB humans fitted in Blender (build/models/figure), then packed
if [ "$step" = all ] || [ "$step" = fit ]; then
  "$BLENDER" -b -P scripts/models/build_figure.py -- fit $2 2>&1 | grep -E "^FIGURE|Error|error:|Traceback|File \"" || true
fi
if [ "$step" = all ] || [ "$step" = pack ]; then
  "$PY" scripts/models/build_figure.py pack
fi
"$PY" scripts/models/build_models.py report
