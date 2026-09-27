#!/bin/sh
# Rebuild Resources/Models from the raw downloads (sources and licences: LICENSES/THIRD_PARTY.md).
# Usage: scripts/models/build.sh [skeleton|internals|skin [variant]|report]   (default: everything)
# Tools live outside git in $EVERYBODY_TOOLS (default ./tools):
#   Blender.app            official macOS arm64 build (4.5 LTS), copied out of the .dmg
#   downloads/Z-Anatomy/   Startup.blend from github.com/Z-Anatomy/Models-of-human-anatomy (Z-Anatomy.zip)
#   blender-user/          Blender user dir with the MPFB2 extension + makehuman_system_assets_cc0 in
#                          extensions/.user/user_default/mpfb/data
set -e
cd "$(dirname "$0")/../.."
TOOLS=${EVERYBODY_TOOLS:-$PWD/tools}
BLENDER="$TOOLS/Blender.app/Contents/MacOS/Blender"
export BLENDER_USER_RESOURCES="$TOOLS/blender-user"
step=${1:-all}
if [ "$step" = all ] || [ "$step" = skeleton ]; then
  "$BLENDER" -b "$TOOLS/downloads/Z-Anatomy/Startup.blend" -P scripts/models/build_models.py -- skeleton 2>&1 | grep -E "^(SKELETON|SKIN)|Error|error:" || true
fi
if [ "$step" = all ] || [ "$step" = internals ]; then
  "$BLENDER" -b "$TOOLS/downloads/Z-Anatomy/Startup.blend" -P scripts/models/build_internals.py 2>&1 | grep -E "^INTERNALS|Error|error:" || true
fi
if [ "$step" = all ] || [ "$step" = skin ]; then
  "$BLENDER" -b -P scripts/models/build_models.py -- skin $2 2>&1 | grep -E "^(SKELETON|SKIN)|Error|error:" || true
fi
${PYTHON:-venv/bin/python} scripts/models/build_models.py report
