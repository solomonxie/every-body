#!/bin/sh
# Contact sheets of the outer figure: heritages × sex, ages, pregnant, underwear on/off.
# Usage: scripts/render_body/grid.sh out-dir [heritage|ages|underwear|inside|faces]…   (default: all)
set -e
cd "$(dirname "$0")/../.."
OUT=${1:-/tmp/figure-grid}
shift || true
PY=${PY:-venv/bin/python}
[ -x "$PY" ] || PY=../../../venv/bin/python
mkdir -p "$OUT/tiles"
R=scripts/render_body/render.sh
want() { [ $# -eq 0 ] || [ -z "$SHEETS" ] || echo " $SHEETS " | grep -q " $1 "; }
SHEETS="$*"
HERITAGES="southeast-asian south-asian hispanic white black"
T="$OUT/tiles"

if want heritage; then
  for sex in male female; do
    for h in $HERITAGES; do HERITAGE=$h $R "$T/$sex-$h.png" skin 0 - - $sex adult >/dev/null; done
    "$PY" scripts/render_body/sheet.py "$OUT/heritage-$sex.png" $(for h in $HERITAGES; do echo "$T/$sex-$h.png"; done)
  done
fi
if want faces; then
  for sex in male female; do
    for h in $HERITAGES; do HERITAGE=$h $R "$T/face-$sex-$h.png" skin 0 1.45 1.0 $sex adult >/dev/null; done
    "$PY" scripts/render_body/sheet.py "$OUT/faces-$sex.png" $(for h in $HERITAGES; do echo "$T/face-$sex-$h.png"; done)
  done
fi
if want ages; then
  for sex in male female; do
    for a in infant toddler child adult senior; do $R "$T/age-$sex-$a.png" skin 0 - - $sex $a >/dev/null; done
    "$PY" scripts/render_body/sheet.py "$OUT/ages-$sex.png" $(for a in infant toddler child adult senior; do echo "$T/age-$sex-$a.png"; done)
  done
  PREGNANT=1 $R "$T/pregnant.png" skin 0 - - female adult >/dev/null
  PREGNANT=1 $R "$T/pregnant-side.png" skin 1.57 - - female adult >/dev/null
  "$PY" scripts/render_body/sheet.py "$OUT/pregnant.png" "$T/pregnant.png" "$T/pregnant-side.png"
fi
if want underwear; then
  for sex in male female; do
    $R "$T/uw-$sex-on.png" skin 0 - - $sex adult >/dev/null
    $R "$T/uw-$sex-back.png" skin 3.14 - - $sex adult >/dev/null
    UNDERWEAR=0 $R "$T/uw-$sex-off.png" skin 0 - - $sex adult >/dev/null
  done
  "$PY" scripts/render_body/sheet.py "$OUT/underwear.png" "$T/uw-male-on.png" "$T/uw-male-back.png" "$T/uw-male-off.png" \
    "$T/uw-female-on.png" "$T/uw-female-back.png" "$T/uw-female-off.png"
fi
# skeleton and organs under a see-through skin, each age
if want inside; then
  for a in infant toddler child adult senior; do
    GLASS=0.45 $R "$T/in-$a.png" skin,skeletal,organs 0 - - male $a >/dev/null
    GLASS=0.45 $R "$T/in-side-$a.png" skin,skeletal,organs 1.57 - - female $a >/dev/null
  done
  "$PY" scripts/render_body/sheet.py "$OUT/inside-front.png" $(for a in infant toddler child adult senior; do echo "$T/in-$a.png"; done)
  "$PY" scripts/render_body/sheet.py "$OUT/inside-side.png" $(for a in infant toddler child adult senior; do echo "$T/in-side-$a.png"; done)
fi
ls "$OUT"/*.png
