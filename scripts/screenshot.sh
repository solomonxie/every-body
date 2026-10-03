#!/bin/sh
# Simulator screenshots, screens opened by launch arguments (SCREENSHOTS build only, never in `make release`).
#   scripts/screenshot.sh install                     build Release + SCREENSHOTS, install on the booted simulator
#   scripts/screenshot.sh shot <out.png> <wait> [args] e.g. shot /tmp/x.png 25 -screen viewer/skeletal -part femur-l
#   scripts/screenshot.sh all <dir>                   the App Store set, 01-…10-
# Args: -screen <viewer|reflex|illustration|posture|info>/<id> -part <id> -point <id> -face <id> -zone <id>
#       -yaw <radians> -trainer YES -credits YES -cardBottom YES
set -e
cd "$(dirname "$0")/.."
. ./.env.local
SIM=${SIM:-$(xcrun simctl list devices booted | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | head -1)}
: "${SIM:?boot a simulator first}"

shot() {
  out=$1; wait=$2; shift 2
  xcrun simctl launch --terminate-running-process "$SIM" "$IOS_BUNDLE_ID" -AppleLanguages '(en)' "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$SIM" screenshot "$out" >/dev/null 2>&1
  echo "$out"
}

case $1 in
install)
  xcodegen generate --quiet
  xcodebuild -project EveryBody.xcodeproj -scheme EveryBody -configuration Release -destination "id=$SIM" \
    PRODUCT_BUNDLE_IDENTIFIER="$IOS_BUNDLE_ID" STORE=us CODE_SIGNING_ALLOWED=NO \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) SCREENSHOTS' -derivedDataPath build/sim build | grep -E "error:|BUILD"
  xcrun simctl install "$SIM" build/sim/Build/Products/Release-iphonesimulator/EveryBody.app
  xcrun simctl status_bar "$SIM" override --time 9:41 --dataNetwork wifi --wifiBars 3 --cellularBars 4 \
    --batteryState charged --batteryLevel 100
  xcrun simctl ui "$SIM" appearance light ;;
shot) shift; shot "$@" ;;
all)
  d=${2:?usage: $0 all <dir>}; mkdir -p "$d"
  shot "$d/01-full-body.png" 25 -screen viewer/body
  shot "$d/02-skeleton.png" 25 -screen viewer/skeletal -part femur-l
  shot "$d/03-muscles.png" 25 -screen viewer/muscular
  shot "$d/04-organs.png" 25 -screen viewer/organs -part heart
  shot "$d/05-acupuncture.png" 25 -screen viewer/acupuncture -point acu-li4 -cardBottom YES
  shot "$d/06-foot-chart.png" 25 -screen reflex/foot -face sole -zone sole-heart
  shot "$d/07-cpr.png" 10 -screen illustration/cpr
  shot "$d/08-cpr-practice.png" 25 -screen illustration/cpr -trainer YES
  shot "$d/09-posture.png" 15 -screen posture/sitting
  shot "$d/10-home.png" 10
  xcrun simctl terminate "$SIM" "$IOS_BUNDLE_ID" ;;
*) sed -n 2,7p "$0"; exit 1 ;;
esac
