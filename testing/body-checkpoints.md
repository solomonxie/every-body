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

## Focus

Until 2026-11-13: adult woman only (`*.female.adult.*`). Other rows wait.

## Pick order

1. User-reported cells (below), until signed off on device
2. Extremes: XXL-XXL, pregnant, senior, infant; max bends; top-down / low-up
3. Random `--sample` per heritage, rotating

Render: app renderer `scripts/render_body/render.sh` (needs Mac unlocked), else headless Blender with the app's lights.

## Open (user-reported)

| Cells | Issue | State |
|---|---|---|
| `*.female.adult.*.*.left\|right\|front-3q-*.back-*` | belly creases on back bend | fixed in Blender port (hip + spine curve), uncommitted, installed; check on device |
| `*.female.pregnant.*.*.*.back-60\|back-90` | hand skin stretches into a sheet to the hips; soft fold low on bump | fixed in Blender port (bind on plain adult body; bump turns over a longer stretch), uncommitted, installed; check on device |
| `east-asian.female.adult.*.base.face-*.*` | cheeks/jaw uneven colour, diagonal line | blush spread evenly (0a82573), installed; check on device |
| `*.female.adult.*.XXL-XXL.top-down\|back-3q-*.*` | butt/thigh lumps | improved afcef5f, unconfirmed |
| `east-asian.female.adult.*.*.face-side.rest` | chin, eyes, sallow skin | improved 8200035, unconfirmed |
| `*.*.adult\|pregnant\|child.*.*.*.shoulder-90\|shoulder-160\|back-*+shoulder-*` | side-chest balloon; armpit skin stretched into thin sheets/flaps (deltoid skin bound to the shoulder blade, turn ramped over a few triangles) | fixed in Blender port (shoulder share: arm/torso split + 0.14 band by distance over the skin, chord blend), uncommitted, installed; check on device. Left: shoulder top squashes (hidden), kid top armhole shows a speck of skin at 160 |
| `*.female.adult.dressed.XL+.*.*` | soft crease where the bra panel meets the steep inner breast wall | open |
| `*.female.pregnant.dressed.XXL.*.*` | bra-pregnant-xxlarge ~2100 clip pts in pose.py (port may miss the pregnant chest shape) | waits |
| `*.female.pregnant.*.base.*.*` with XL/XXL chest | breast underside sinks up to 2 cm into the bump (hidden in the crease) | open (prototype: lift along the bump normal, /tmp/uw/tools/bumpfit.py) |
| `*.*.adult.*.*.*.shoulder-160` | top of shoulder slightly squashed after armpit smoothing (man max stretch 4.7×) | check on device |
| `*.*.child.*.base.face-side.rest` | sharp faceted flap in front of the ear (base-head ears moved rigidly) | open |
| `black.female\|*.male\|*.child.*.base.low-up.rest` | thin white eyeball sliver under the lower lid | open |
| `black.female.adult.bare.base.face-side\|front-3q-*.rest` | small white wedge at the mouth corner (3/4), thin lower-lip edge in profile (coarse mesh) | open |
| `*.female.adult.bare.base.top-down.rest` | grey line at lower lash roots (lash geometry) | open |
| `*.female.adult.*.*.face-*.rest` | woman hair regrown (counts −3%); check looks same on device | check |
| `*.female.adult.*.XL+-*.*.back-*\|shoulder-160` | breasts ignore gravity / arm lift (prototype /tmp/ke/mx/pose_b.py) | feature, user: later |
| `*.female.pregnant.dressed.*` | briefs vs wrist at the hip (no arm swing on pregnant) | waits (not adult woman scope) |

## Open (sweep 2026-10-14)

| Cells | Issue | State |
|---|---|---|
| `*.*.adult.*.*.side.shoulder-160` | hard arm/torso edge, shallow back-armpit groove | open |
| `*.female.adult.*.*.*.elbow-*` | outer elbow outline faceted (mesh density) | open |
| `*.female.adult.dressed.XXL-*.*.back-90` | bra cup lower edge crumples, band edge wavy | open |
| `*.male\|child.*.*.*.shoulder-*` | back-armpit slit (fix applied to the woman only) | waits |

## In progress

- (none)

## Log

| Date | Cells | Result | Commit |
|---|---|---|---|
| 2026-10-13 | `*.female.adult.*.L+.*.*` hips/chest | hips refined, smooth round | 7474a1e |
| 2026-10-13 | belly/hip skin, all sizes | slivers flipped, faired | 1816ce5 |
| 2026-10-13 | east-asian face cheeks | smoothed, hue evened | 2733286 |
| 2026-10-13 | `*.adult.*.*.side\|front-3q-*\|top-down.back-30..90` | back bend: hip share + spine curve, 0 folded tris (was ~1.6k) | uncommitted |
| 2026-10-13 | `*.female.pregnant.*.*.*.back-60\|back-90`, XXL/man back-90 | skin binds on the plain adult body (bones at rest): no hip skin on the arms; front skin spread: squashed tris 785→0 (pregnant), 1430→0 (XXL), 114→0 (man) | uncommitted |
| 2026-10-13 | `east-asian.female.adult.*.*.face-*.rest` | cheek blush patch edge = the line; blush spread, gap 4.4→1.4 a* | 0a82573 |
| 2026-10-13 | `*.female.pregnant.dressed.XL\|XXL.*.*` | plain XL/XXL bra stretched over the bump top as a V panel; own cut on the bump (bra-pregnant-xlarge/xxlarge): band level | 334e336 + Figure.swift uncommitted |
| 2026-10-13 | `*.female.adult.*.*.*.shoulder-160` | side-chest balloon gone (577 mid-weight torso verts no longer swung round the pivot) | uncommitted |
| 2026-10-13 | `*.female.adult\|pregnant.dressed.XXL-XXL.*.rest\|back-60\|back-90\|knee-135` | briefs/bra follow the bends; no new clipping (≤16 verts, ≤5 mm); knee-135 no garment effect | — |
| 2026-10-13 | `*.*.child.bare.base.face-*\|front-3q-*\|low-up.rest` | shelf + dark oval ringing the lower lids (Rain's sockets met the kept eye zone in a step): eye zone blends wide, lids a touch more open; needs face_fit kid-child + hair + pack | this branch |
| 2026-10-13 | `*.male.senior\|adult.*.*.face-*\|top-down.rest`, boys | receding hairline notched, two holes at the front (rim picks snapped to forehead vertex rows): rim line smoothed; needs hair + pack | this branch |
| 2026-10-13 | `*.*.toddler.*.base.face-front.rest` | mouth-corner line = Blender cast shadow (app lights cast none), not a defect | — |
| 2026-10-13 | `*.female\|male.adult.*.M-M\|XXL-XXL\|base.*.shoulder-90\|shoulder-160\|elbow-145\|back-60+shoulder-90`, pregnant + child shoulder-160 | armpit sheets gone: max edge stretch 41–49× → 3.5–4.4×, creases 60–99 → 9–26 (shoulder-160); elbow unchanged and clean | uncommitted |
| 2026-10-13 | `*.*.adult\|senior.bare.base.back*\|face-*.*` | skins clean; upper-back patch + lip smear were a QA tool artifact (pose.py flipped UV v) | — |
| 2026-10-13 | `*.female.*.dressed.*.*.rest\|back-*\|back-60+shoulder-90` | strap line kept ≤0.17 out over the shoulder: ruffle/notches gone (edge wave 17–25→9–10 mm) | 0499f0b |
| 2026-10-13 | `*.*.adult.*.*.back*\|left\|low-up.shoulder-160` | shoulder shares band 0.2 + 40 smoothing passes: armpit creases →0, strap straight | uncommitted |
| 2026-10-13 | `*.female.adult\|senior.*.base.face-*\|front-3q-*.rest` | mouth lining out of tuck_lips push + seat_lining guard: lip-corner triangles gone | f755006 |
| 2026-10-14 | `*.female.adult.*.*.*.knee-*\|elbow-*` | outer-side hinge share widened; inner skin pressed to the mid plane: crossing 350 verts/83 mm → 0 | uncommitted |
| 2026-10-14 | `*.female.adult.*.base.face-side\|front-3q-*.rest` | ears turn with their skin (no lobe-jaw ledge); lip-corner folds eased (back-facing px ~1000→0) | a166c77, repack |
| 2026-10-14 | mixed shapes × back/shoulder/elbow | neck, elbow+back, belly clean; model defects found (above) | — |
| 2026-10-14 | `*.female.adult.dressed.*.rest\|knee-*`, knee front, armpit/bra on wide hips | briefs bridge creases (clip →0); knee front refined (+1.5k verts); arm-swing mask smooth (bra-small clip 143→22); XXL bra 782→144 | f93760f |
| 2026-10-14 | `*.*.*.dressed.*` | underwear black for women, white below adult (user request) | fb1d669 |
| 2026-10-14 | `*.female.adult.*.XXL-*.back*`, `*.female.adult.*.S-*.*.back-60` | briefs film pushed along own normal (cleft notch gone, clip 0); hip-front edges even + trunk front faired (lumps 0.98→0.19 mm) | 85e1872 |
| 2026-10-14 | `*.female.adult.bare.base.face-side\|front-3q-*\|low-up\|top-down.rest` | inner-corner panel over the eyeball tucked behind the ball; under-eye/nose-side line smoothed (all heritages) | 773505d, repack |
| 2026-10-14 | `*.female.adult.*.XL\|XXL-*.*.rest\|back-60\|back-90` | under-breast fold opened (gap 0.9→15 mm), breast carries the hips change; bra-xxlarge under-breast clip 120→0 | 93261b8, repack |
| 2026-10-14 | `*.female.adult.bare.base.face-*\|front-3q-*\|top-down.rest` | caruncle toned to soft pink; lower-lid ledge tucked under the ball (no pale rim); lips closed in profile (lining px ~500→0) | 7bb6857, repack |
| 2026-10-14 | `*.female.adult.dressed.L+-*.*.rest\|back-*` | bra V tip rounded, cup sheet spans the centre panel (facets 16→0); strap clear of skin (clip 22–24→≤2 pts, −3.8→−1.3 mm) | af1cd1b, repack |
| 2026-10-14 | `black\|south-asian.female.adult.bare.base.face-*\|front-3q-*.rest` | lower lip tucked under the upper (rim-light px 513→85 at 3/4); inner-corner sheen hollowed (grey px 4204→1200 black, 221→6 south-asian) | aef1e52, repack |
| 2026-10-14 | `*.female.adult.dressed.*.*.shoulder-*\|back-*+shoulder-*` | briefs no longer stretch to the hanging hand (garmentShare fallback: same-holder skin; float 174→14 mm) | uncommitted |
| 2026-10-14 | `*.female.adult.*.*.back\|low-up.shoulder-160\|back-60+shoulder-90` | slit behind the armpit softened (fold clusters 23–31→0) | 4a5b950, repack |
