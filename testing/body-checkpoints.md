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
| `*.female.adult.*.XXL-XXL.top-down\|back-3q-*.*` | butt/thigh lumps | buttocks confirmed clean (sweep3); inner-thigh ridges reopened below |
| `east-asian.female.adult.*.*.face-side.rest` | chin, eyes, sallow skin | skin/eyes confirmed (sweep3); chin recedes (style call) |
| `*.*.adult\|pregnant\|child.*.*.*.shoulder-90\|shoulder-160\|back-*+shoulder-*` | side-chest balloon; armpit skin stretched into thin sheets/flaps (deltoid skin bound to the shoulder blade, turn ramped over a few triangles) | fixed in Blender port (shoulder share: arm/torso split + 0.14 band by distance over the skin, chord blend), uncommitted, installed; check on device. Left: shoulder top squashes (hidden), kid top armhole shows a speck of skin at 160 |
| `*.female.adult.dressed.XL+.*.*` | soft crease where the bra panel meets the steep inner breast wall | fixed dfca54a (fill_gore), committed; install pending phone |
| `*.female.pregnant.dressed.XXL.*.*` | bra-pregnant-xxlarge ~2100 clip pts in pose.py (port may miss the pregnant chest shape) | waits |
| `*.female.pregnant.*.base.*.*` with XL/XXL chest | breast underside sinks up to 2 cm into the bump (hidden in the crease) | open (prototype: lift along the bump normal, /tmp/uw/tools/bumpfit.py) |
| `*.*.adult.*.*.*.shoulder-160` | top of shoulder slightly squashed after armpit smoothing (man max stretch 4.7×) | check on device |
| `*.*.child.*.base.face-side.rest` | sharp faceted flap in front of the ear (base-head ears moved rigidly) | open |
| `black.female\|*.male\|*.child.*.base.low-up.rest` | thin white eyeball sliver under the lower lid | open |
| `black.female.adult.bare.base.face-side\|front-3q-*.rest` | small white wedge at the mouth corner (3/4), thin lower-lip edge in profile (coarse mesh) | fixed: specular mask skin-seam.png (4a9d805) + Figure.swift (uncommitted), installed; check on device for glancing sheen. Thin lower-lip edge in profile still open |
| `*.female.adult.*.*.face-*.rest` | woman hair regrown (counts −3%); check looks same on device | check |
| `*.female.adult.*.XL+-*.*.back-*\|shoulder-160` | breasts ignore gravity / arm lift (prototype /tmp/ke/mx/pose_b.py) | feature, user: later |
| `*.female.pregnant.dressed.*` | briefs vs wrist at the hip (no arm swing on pregnant) | waits (not adult woman scope) |

## Open (sweep 2026-10-14)

| Cells | Issue | State |
|---|---|---|
| `*.female.adult.*.*-XXL.left\|right\|front-3q-*.rest\|back-*` | sharp diagonal crease at the waist side above the hip bone, XXL hips only, strongest at back-60 (sweep3 /tmp/sweep3/crops/xx-white-back-60-left-flank.png) | fixed f282694 (fair_flank on hips-*), c31cf5c; install pending phone. Check S-XXL sitting hip-front edge |
| `*.female.adult.*.*.top-down.*` | 3-4 ridges on the inner thigh (base mesh, all hips) | open |
| `*.female.adult.*.*.back.back-60+shoulder-90` | bright vertical knob where the arm meets the back | fixed (Swift: exact chord Jacobian normals + band normal smoothing, uncommitted); install pending phone |
| `*.female.adult.*.*.front-3q-left.back-60+shoulder-90` | lumpy chest/rib shading under the raised arm, sharp front-armpit line | fixed (same change); shoulder-45 arm normal error up slightly (11.7 -> 17.4 p90) |
| `*.female.adult.bare.*.left\|front-3q-*.rest` | faint horizontal step across mid-thigh (KNEE_REFINE band edge) | open |
| `*.female.adult.dressed.XXL-XXL.back\|top-down.shoulder-160` | bra strap edge ripple near armpit | open (minor) |
| `*.female.adult.*.*.*.elbow-145` | thin lit line at the inner crease end (no contact occlusion; 25% fewer bright px after refine) | fixed: contact-shade overlay (Swift, uncommitted); check on device incl. elbow-90 dimple, overlay flicker, glass-skin view |
| `*.female.adult.*.*.*.knee-135` | bright sliver in the knee pit (~115 px in pit close-up) | 113 -> 22 px via contact shade; pale grey wedge left |
| `*.female.adult.*.*.side\|back-3q-*.shoulder-160` | back of shoulder still a rounded bump; faint diagonal crease on the back armpit fold; shoulder relax frame time unchecked on device | fixed (Swift: convex cut fades behind the pivot, uncommitted), installed. Left: relax est. 3-8 ms/frame (flatten neighbour lists if slow) |
| `*.female.adult.dressed.M-XL\|XXL.*.*` | bra-medium on wide hips still creases (162 edges); bra-xlarge small cluster below the nipple | fixed ef04b92/8ea3244, installed. Left: small dense patch above the nipple on bra-xlarge/xxlarge |
| `*.female.adult.*.*.*.knee-135` | front-of-knee stretch (218 edges >2), small notch in the knee pit; thin bright sliver in inner elbow crease | fixed (Swift, uncommitted), installed. Left: elbow-145 sliver, faceted knee front outline at 135 |
| `*.female.adult.*.XXL-XXL.back\|left.back-*` | second dip at the fullest point of large buttocks (hip pivot far from the skin) | halved (Swift BackBend raise, uncommitted), installed |
| `*.female.adult.*.*.top-down.elbow-*` | forearm outline beyond the refined band still coarse | fixed f38ba3f (FOREARM_REFINE, ELBOW_FRONT_REFINE, 2nd KNEE_REFINE; +4296 tris) |
| `*.female.adult.dressed.M-*.*.low-up.*` | faint shading lumps where the cup meets the band; small band-edge kink at the side | fixed 148c59c (BAND_SHEET, CUP_RELAX, front panel stops inside band) |
| `*.male\|child.*.*.*.shoulder-*` | back-armpit slit (fix applied to the woman only) | waits |

## In progress

- inner-thigh ridges (top-down) + mid-thigh refine-band step (agent, /tmp/thigh/)
- shoulder-45 arm normal regression, XXL shoulder-160 strap ripple, shoulder 0-60 sweep (agent, /tmp/sh45/)

## Log

- 2026-10-15: waist-side crease faired (XXL-XXL edges >15 deg 15 -> 0; L-XL 13-15 -> 2), clipping unchanged.

- 2026-10-15: shoulder band normals now from the chord's full Jacobian (share gradient) + 20 smoothing passes; shoulder-90 back-pit normal error p90 37.7 -> 12.6 deg; positions unchanged.

- 2026-10-15: crease contact shadow at runtime (pressed() occlusion -> unlit black alpha overlay); elbow-145 line gone, knee-135 pit 113 -> 22 bright px; rest/shoulder/back pixel-identical.

- 2026-10-15: forearm edges 52 -> 28 mm (outline step 23 -> 16 deg), knee-135 front outline step 47 -> 24 deg, inner elbow 27 -> 14 mm edges. Body 84106 -> 88402 tris.

- 2026-10-15: XL+ cleavage crease filled (valley curvature p99 XL 88 -> 31 rest, 138 -> 55 back-60); S/M/L also cleaner. Band-centre normal noise up slightly (1.4-4.0 deg p99), XL-M centre-line slivers 15 -> 24 (not visible).

- 2026-10-15: mouth-corner white wedge removed on all adult-woman heritages via lip-seam specular mask (near-white px 6957 -> 348 over 5 views).

- 2026-10-15: bra band below cups smoothed (p99 noise 4-9 -> 0.6-2.2 deg), hem level (4.3-5.0 -> 1.3-1.9 mm), tip slivers 21-27 -> 3 (XXL 12-14 at back-60/shoulder-90 left). XL+ cleavage crease still open.

- 2026-10-15: inner-corner white streak fixed (TUCK_LIDS female-adult, eac2361; SE-Asian front 642 -> 1 bright px). 'Lash sheen' was rk.py default material, not the app. tuck_lips fade past mouth corners pushes cheek into upper lip (noted, not fixed).

- 2026-10-15: shoulder-160 back knob and back armpit crease fixed (strap clip 55 -> 1, bent edges behind shoulder 36 -> 16). Swift only.

- 2026-10-15: XXL buttock second dip halved in back bends (100 -> 46 deg/m at back-90): skin >10 cm behind the hip pivot turns higher (BackBend raiseFrom 0.1, raise 1). Swift only.

- 2026-10-15: cup creases fixed on M-XL/M-XXL/S-XXL/XL-M/XL-XXL (bent edges near nipple 162 -> 0 worst); hips move each breast rigidly, nipple patch bound to one triangle. Left: small dense patch above nipple on bra-xlarge/xxlarge (2-12 mild edges).

- 2026-10-15: knee-135 front stretch fixed (0 edges >2x, was 218), knee-pit notch and elbow-90 spot mostly gone; Swift only, installed. Elbow-145 sliver and faceted knee front outline still open.

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
| 2026-10-14 | hip squeeze scene (user feature) | partner forearms reach back level, cuff blobs gone; installed | uncommitted |
| 2026-10-15 | `*.female.adult.bare.base.top-down\|front-3q-*.rest` | grey line = upper lash roots edge-on; roots seated up into the lid: dark lash line | c9a039d, repack |
| 2026-10-15 | `*.female.adult.dressed.*.*.back-90` | bra band wraps over the sternum hollow as a hoop (dip 10→2 mm M, 3.6→0.9 mm XXL): straight hem when bent | ddc2a51, repack |
| 2026-10-15 | `*.female.adult.*.*.*.shoulder-90\|shoulder-160` | chord-blend normals turn with the surface; band skin relaxed (min-dot −0.3→0.74, faces <0.5 dot ~27→0, bra clip 118→62) | uncommitted |
| 2026-10-15 | `*.female.adult.*.*.*.elbow-*` | elbow back refined (+1704 verts): outline corner 28–40°→10–15° | 7e19560, repack |
| 2026-10-15 | `*.female.adult.dressed.*.*.*` other-hips cups | hips delta eased over the breasts: cup creases near the nipple 34–137→0–22 edges | d59c4cf, repack |
| 2026-10-15 | `*.female.adult.*.*.*.knee-*\|elbow-145` | pressed skin's normal faces the contact: lit crease sliver gone (>45° off 220→24) | uncommitted |
| 2026-10-15 | `*.female.adult.*.*.side.elbow-*\|knee-*` | hinge extensor ramp over limb depth, not sign: side seam gone (stretch 2.53→1.76) | uncommitted |
| 2026-10-15 | `*.female.adult.*.*.back\|left.back-*` | hip share fades out higher (hipBandUp 0.30), into the spine curve: shelf dip 122–158→20–40 °/m (XXL 148→100) | uncommitted |
