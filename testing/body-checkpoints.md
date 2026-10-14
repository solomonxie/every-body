# 3D body checkpoints

Visual QA of the skin figure. Every checkpoint = one cell of the product below.
Expand: `venv/bin/python testing/checkpoints.py [--count] [--filter east-asian bare] [--sample 5]`

## Dimensions

| Dimension | Values |
|---|---|
| heritage | white, black, hispanic, south-asian, southeast-asian, east-asian |
| person | infant, toddler/child/adult/senior × female/male, pregnant |
| clothing | dressed (underwear), bare |
| shape | adult woman: chest S–XXL × hips S–XXL; others: base |
| view | front, back, left, right, front-3q-left/right, back-3q-left/right, top-down, low-up, face-front, face-side |
| pose | rest; back 30/60/90; neck turn 70; shoulder 90/160; elbow 90/145; knee 90/135; back+shoulder, back+elbow; sitting |

ID: `heritage.sex.age.clothing.shape.view.pose`, e.g. `east-asian.female.adult.bare.XXL-XXL.top-down.back-60`

## What to look for

- skin: facets, lumps, creases, folds, self-intersection, seams
- colour: blotches, bands, streaks, sallow/grey tone, face vs body mismatch
- shape: silhouette corners, proportions, symmetry, face prettiness (esp. profile)
- joints: limbs detaching, candy-wrapper twist, skin pinching, internals poking out
- garments, hair, eyes, lashes: gaps, clipping, floating

## Pick order

1. User-reported cells (below), until signed off on device
2. Extremes: XXL-XXL, pregnant, senior, infant; max bends; top-down / low-up
3. Random `--sample` per heritage, rotating

Render: app renderer `scripts/render_body/render.sh` (needs Mac unlocked), else headless Blender with the app's lights.

## Open (user-reported)

| Cells | Issue | State |
|---|---|---|
| `*.female.adult.*.*.left\|right\|front-3q-*.back-*` | belly creases on back bend | fixed in Blender port (hip + spine curve), uncommitted, installed; check on device |
| `*.female.pregnant.*.*.*.back-60\|back-90` | hand skin stretches into a sheet to the hips; soft fold low on bump | queued |
| `east-asian.female.adult.*.base.face-*.*` | cheeks/jaw uneven colour, diagonal line | fixing |
| `*.female.adult.*.XXL-XXL.top-down\|back-3q-*.*` | butt/thigh lumps | improved afcef5f, unconfirmed |
| `east-asian.female.adult.*.*.face-side.rest` | chin, eyes, sallow skin | improved 8200035, unconfirmed |

## Log

| Date | Cells | Result | Commit |
|---|---|---|---|
| 2026-10-13 | `*.female.adult.*.L+.*.*` hips/chest | hips refined, smooth round | 7474a1e |
| 2026-10-13 | belly/hip skin, all sizes | slivers flipped, faired | 1816ce5 |
| 2026-10-13 | east-asian face cheeks | smoothed, hue evened | 2733286 |
| 2026-10-13 | `*.adult.*.*.side\|front-3q-*\|top-down.back-30..90` | back bend: hip share + spine curve, 0 folded tris (was ~1.6k) | uncommitted |
