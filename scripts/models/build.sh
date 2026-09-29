#!/bin/sh
# Rebuild Resources/Models from the raw downloads (sources and licences: LICENSES/THIRD_PARTY.md).
# Usage: scripts/models/build.sh [skeleton|fit [group]|pack|internals|postures|report]   (default: everything; fit: figures, faces, hair)
# Tools live outside git in $EVERYBODY_TOOLS (default ./tools):
#   Blender.app            official macOS arm64 build (4.5 LTS), copied out of the .dmg
#   downloads/Z-Anatomy/   Startup.blend from github.com/Z-Anatomy/Models-of-human-anatomy (Z-Anatomy.zip)
#   downloads/blender-studio/  snow/snow_v02.blend, rain/rain_rig.blend from studio.blender.org/characters (CC BY)
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
  # the heads and hair faces are drawn onto (downloads/blender-studio: Snow and Rain, CC BY)
  "$BLENDER" -b "$TOOLS/downloads/blender-studio/snow/snow_v02.blend" -P scripts/models/base_head.py -- snow 2>&1 | grep -E "^BASEHEAD|Error" || true
  "$BLENDER" -b "$TOOLS/downloads/blender-studio/rain/rain_rig.blend" -P scripts/models/base_head.py -- rain 2>&1 | grep -E "^BASEHEAD|Error" || true
  # faces: the base-mesh heads, drawn toward the sample averages (scripts/models/faces.npz)
  "$PY" scripts/models/face_fit.py $2 2>&1 | grep -vE "^(W|I)0000|absl|GetPrototype|warnings.warn" || true
  "$BLENDER" -b -P scripts/models/build_figure.py -- hair $2 2>&1 | grep -E "^FIGURE|Error|error:|Traceback|File \"" || true
fi
if [ "$step" = all ] || [ "$step" = pack ]; then
  "$PY" scripts/models/build_figure.py pack
  # points and meridians onto the new skin (snap_points.py, via the generator)
  "$PY" scripts/gen_body.py
fi
# after the figures: muscles are clamped under the adult skins
if [ "$step" = all ] || [ "$step" = internals ]; then
  "$BLENDER" -b "$TOOLS/downloads/Z-Anatomy/Startup.blend" -P scripts/models/build_internals.py 2>&1 | grep -E "^INTERNALS|Error|error:" || true
fi
# posture scenes: the shipped figure and inner models re-posed (after pack and internals)
if [ "$step" = all ] || [ "$step" = postures ]; then
  "$BLENDER" -b -P scripts/models/build_postures.py -- extract 2>&1 | grep -E "^POSTURES|Error|error:" || true
  "$PY" scripts/models/build_postures.py pack
fi
"$PY" scripts/models/build_models.py report
