#!/bin/sh
# Render Explore tile thumbnails from the schematic body (needs Google Chrome).
# Usage: scripts/thumbnails/render.sh   → assets/images/tiles/<system>.png
set -e
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
OUT=/tmp/body-atlas-thumbs
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
rm -rf "$OUT" && mkdir -p "$OUT"

cat > "$OUT/tsconfig.json" <<JSON
{ "compilerOptions": { "module": "es2020", "target": "es2020", "moduleResolution": "bundler", "skipLibCheck": true,
  "outDir": "$OUT", "rootDir": "$ROOT/src", "ignoreDeprecations": "6.0", "baseUrl": "$ROOT", "paths": { "@/*": ["./src/*"] } },
  "files": ["$ROOT/src/data/body/index.ts", "$ROOT/src/data/anatomy.ts"] }
JSON
npx tsc -p "$OUT/tsconfig.json"
find "$OUT" -name "*.js" -exec perl -pi -e "s#from '(\./[^']+?)(\.js)?'#from '\$1.js'#g" {} \;
cp scripts/thumbnails/tile.html node_modules/three/build/three.module.js "$OUT/"

tile() { # id, hash
  timeout 25 "$CHROME" --headless=new --no-first-run --user-data-dir="$OUT/profile" --allow-file-access-from-files \
    --use-angle=swiftshader --enable-unsafe-swiftshader --virtual-time-budget=4000 \
    --screenshot="$ROOT/assets/images/tiles/$1.png" --window-size=360,360 "file://$OUT/tile.html#$2" >/dev/null 2>&1 || true
  echo "  $1"
}

tile skeletal 'layers=skeletal&y=0.9&d=2.6'
tile muscular 'layers=muscular,skeletal&y=0.6&d=3'
tile circulatory 'layers=circulatory,organs&skin=0.15&y=0.7&d=3'
tile nervous 'layers=nervous,organs&skin=0.15&y=0.3&d=4.4'
tile organs 'layers=organs&skin=0.15&y=0.6&d=2.6'
tile digestive 'layers=organs&skin=0.1&y=0.45&d=2.2'
tile acupoint-reflex-map 'layers=organs&skin=0.55&y=0.1&d=4.2'
