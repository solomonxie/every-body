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
| `*.female.adult.dressed.XL+.*.*` | soft crease where the bra panel meets the steep inner breast wall | fixed dfca54a (fill_gore), committed; installed phone |
| `*.female.pregnant.dressed.XXL.*.*` | bra-pregnant-xxlarge ~2100 clip pts in pose.py (port may miss the pregnant chest shape) | waits |
| `*.female.pregnant.*.base.*.*` with XL/XXL chest | breast underside sinks up to 2 cm into the bump (hidden in the crease) | open (prototype: lift along the bump normal, /tmp/uw/tools/bumpfit.py) |
| `*.female.adult.dressed.*.back-3q-*\|right\|top-down.shoulder-90\|160` | back bra strap ripple/facets (garment kept chord pinch; normals ignored relax) | fixed: wrapGarment (Swift, uncommitted), installed; check on device + frame time. Tip of strap at shoulder top still crumpled |
| `*.female.adult.*.*.*.shoulder-90` | upper-arm underside sags, kink near elbow: inner-arm strip bound to back/ribs, share 0.55-0.98 | fixed: inner-arm relabel in shoulderShares (Swift, uncommitted), installed; armpit max stretch +1-4% |
| `*.female.adult.*.*.{left,right,front-3q-*,low-up}.elbow-145\|knee-135` | dark contact-shade patch on open skin (pressed side shaded with no limb over it) | fixed: contactShade by other-side distance (Swift, uncommitted), installed; darkened px elbow front 10353 -> 2785 |
| `*.female.adult.*.*.{left,back-3q-*,back}.knee-135` | notch + lit wedge at the lateral crease end (calf overhangs thigh by ~2.5 cm) | fixed: kneeRim remaps both sides' extent to the mean (Swift, uncommitted), installed; lateral step 9.1 -> 2.4 mm. Faint highlight on upper crease (left view) |
| `*.female.adult.*.*.{front,low-up}.knee-135` | pointed V kneecap front (rest-mesh ridge x~0.14) | open, low: fairing doesn't help; needs kneecap resculpt in the fit (changes rest look) |
| `*.female.adult.dressed.*.low-up.rest` | small pinched folds in briefs gusset | open, cosmetic |
| `*.female.adult.*.*.*.shoulder-90\|160` | upper back/shoulder top slid down with the arm (smoothed arm share reached the spine): hair through neck side, strap crumple, back straps V | fixed: far-share fade in shoulderShares (Swift, uncommitted), installed; check s160 back 'shrug' + man/child shoulders |
| `*.female.adult.dressed.XXL-*.top-down.back-30` | XXL bra band wave (XXL band low in the hips-option zone; hips deltas dropped mid-back skin up to 6 mm) | fixed 46233dc (level() in hips deltas, re-snapped to surface): hem spread XXL-S 7.3 -> 1.4 mm; pushed, installed |
| `*.female.adult.dressed.*.*.rest` | front strap edge slightly wavy at rest (~31 spikes, worst 2.1 mm, all bras) | fixed 46233dc (strap clearance push spread over 2 cm in space, not 10 rings): adult bras 31 -> 0 spikes; senior bra unchanged (no raw); pushed, installed |
| `*.female.adult.*.*.{right,back-3q-*,back}.shoulder-90`, `{right,face-side}.shoulder-160` | back-armpit fold edge ~45 deg (share clipped at 1 across one coarse edge); diagonal crease on the mesh-density seam at s160 (convex leak sank coarse skin) | fixed: shoulderReach + eased arm share, relax leak scaled by edge length (Swift, uncommitted); s90 fold 45 -> 20 deg, s160 shading jump 12.4 -> 7.3 deg; installed |
| `*.female.adult.*.*.face-side\|front-3q-*.shoulder-160` | sharp lit ridge at the front armpit (relaxConvex blocked the relax on a ridge) | softened: ridge-aware convex cut from 110 deg (Swift, uncommitted); fold 44 -> 21 deg; installed |
| `*.female.adult.bare.*.front-3q-*.rest` | bright streak at the sternum between breasts; bright sliver at navel top rim | fixed 82d9d47: back-light glints (fill/rim cast no shadow) masked in skin-seam.png; black sternum S 123 -> 42; pushed, installed; check RealityKit scales grazing glints |
| `*.female.adult.*.*.*.rest\|shoulder-160` | small lit specks along the collarbone near the neck | fixed 82d9d47 (same mask); pushed, installed |
| `*.female.adult.*.*.back-3q-*.*` | bright spot at nape/C7 | halved 82d9d47 (rest is a real upper-back highlight); pushed, installed |
| `*.female.adult.*.*.right\|left\|back-3q-*.knee-90` | dark streaks below the knee crease end (side shade lopsided on an open corner) | fixed: kneeOpen fades side shade below 130 deg (Swift, uncommitted), installed |
| `*.female.adult.*.*.right\|left.knee-90` | dark smudge + lit speck at the lateral crease end | fixed: foldNormal (exact hinge-map normal) + kneeOpen reads plain normal (Swift, uncommitted), installed; peak +122 -> +63. Check knee-110/135 crease ends on device |
| `*.female.adult.*.*.back-3q-*.elbow-145` | bright zigzag tick at the elbow crease end (dark skin); 3 crushed flipped tris | fixed: foldNormal (Swift, uncommitted), installed; bright px 622 -> 357 (black); flipped tris remain, shaded |
| `*.female.adult.dressed.*.back\|back-3q-*.back-60` | briefs top hem notches near the cleft (<=2.7 mm, present at rest) | fixed 5f9cddd (waistband bridged over the cleft in space, 0.75 cm ball): notches 0 on every hips option and pose; figure + sitting bins pushed; installed |
| `*.female.adult.*.*.back-*.back-*` | diagonal highlight on upper back by the spine (sculpted) | open, low (model) |
| posture chin-down keys (laptop, couch, phone-*), sitting upright | short hair (bob, coily) stretched into a bulb (hair blended to upper back by height) | fixed: skull follow from 12 deg forward (PostureScene, uncommitted), installed; phone-standing stretched edges 3580 -> 0. Bob swings with head at 53 deg |
| posture, all keys | lumpy shoulder/chest shading (raw per-vertex normals) | fixed: 2-ring normal blur like Figure.swift (PostureScene, uncommitted), installed; p99 21 -> 7 deg |
| posture sitting front / slouched | strap ends on shoulder tops; wavy bra band top edge (slouched) | fixed ef65212 (posture_rig settle_bra: strap crest offsets eased to the plain lift; cup-sheet points >8 mm off skin bound to a wide skin triangle): strap crest gap max 8.8 -> 3.6-5.1 mm (no tab on the shoulder line), slouched bra faces >20 deg S 1103 -> 731, M 650 -> 475, L 990 -> 769, XXL 1283 -> 1136 (XL 1071 -> 1158), ragged S/M top edge at strap roots gone; bra clip 0 on all 8 bins; all bins repacked, not pushed. Left: L+ gore top edge still dips with the slouched cleavage (skin), tip-zone seam arc on L cups, figure.bin strap crest same 8.8 mm (main figure view) |
| posture sitting slouched, floor k2 | hair on shoulders sheared into a ruff at the nape (head tipped back 22 deg vs T1) | fixed: blend ramp top raised up to 0.16 when head tips back (PostureScene, uncommitted); stretched edges black 2640 -> 818, south-asian 1236 -> 0; hispanic long hair keeps a small ruff; installed |
| posture sitting, `*.dressed.XXL-*.back` | seated briefs back hem low, V at cleft, skin rolls over; briefs in hip crease | fixed 649d7a3/d87c98a (waist_to_pelvis, seated_bridge, crease press): sitting clip 2643/1512/887 -> 39/23/0, hem notches 88/70/78 -> 23/14/16; installed. Left: floor hip crease (~1950 pts, -4.6 mm), small-hips standing notch 1.56 mm, slight dip at t=1 |
| posture laptop k3, phone-* k3/k4 | hispanic long curly hair stretched (head forward) | fixed d7cb566: long hair's lower anchor turned 0.7x head pitch; laptop k3 2739 -> 136, phone-standing k4 5134 -> 2267, phone-bed k3 4685 -> 1406; curly ends lift slightly off nape at 40-53 deg; installed |
| `*.*.adult.*.*.*.shoulder-160` | top of shoulder squashed: partly fixed (shoulderTop keep 1.5, Swift uncommitted, installed): <half-area tris 116 -> 85 of 139, median 0.33 -> 0.40; stronger options creased. Was: top of shoulder slightly squashed after armpit smoothing (man max stretch 4.7×) | check on device |
| `*.*.child.*.base.face-side.rest` | sharp faceted flap in front of the ear (base-head ears moved rigidly) | open |
| `black.female\|*.male\|*.child.*.base.low-up.rest` | thin white eyeball sliver under the lower lid | woman: not eyeball, lid-rim strip catching back light; LIFT_LIDS 0.9 (15e87ee) pale px 5382 -> 3094 (black 2327 -> 1210). Male/child wait |
| `black.female.adult.bare.base.face-side\|front-3q-*.rest` | small white wedge at the mouth corner (3/4), thin lower-lip edge in profile (coarse mesh) | fixed: specular mask skin-seam.png (4a9d805) + Figure.swift (uncommitted), installed; check on device for glancing sheen. Thin lower-lip edge: TUCK_LOWER removed (c247e31), lip fuller; installed |
| `*.*.adult.*.*.*.shoulder-*` | QA port tools/qa/pose.py lacks the shoulder bands + hinge press: shoulder-pose renders untrustworthy | done: shoulderShares/chord/relax, hinge press + contact shade ported (no app dump; bendCrossing/muscles not ported) |
| `hispanic.female.adult.*.*.back-3q-left.*` | curly hair hem tips spiky (lone strand ends smoothed to needles) | fixed d8f0c2c (tip_round 2x over last 2 cm, jitter 0.9 cm): needles 8 -> 3; installed |
| `black.female.adult.*.*.face-side.*` | faint lit sliver on coily hair inner edge at the neck (back-light on curtain/back fold + jaw pit/flap) | fixed d8f0c2c (smooth 200, close 0.6 cm): back-3q fold gone, front folds faint; installed |
| `*.female.adult.*.*.face-*.rest` | woman hair regrown (counts −3%); check looks same on device | check |
| `*.female.adult.*.XL+-*.*.back-*\|shoulder-160` | breasts ignore gravity / arm lift (prototype /tmp/ke/mx/pose_b.py) | feature, user: later |
| `*.female.pregnant.dressed.*` | briefs vs wrist at the hip (no arm swing on pregnant) | waits (not adult woman scope) |
| posture couch (all chests), laptop XL/XXL k2-3, computer XXL k3 | arm sunk into bra (220-509 pts); press refused (<80% cleared) | fixed b1ab6c9 (bra_clear: couch hand back + elbow out, laptop/computer elbows out); all 0; installed |
| posture seated briefs | belly/thigh and crotch folds tuck briefs into the crease (300-680 pts, 60-80% fabric-in-fabric); visible only from below | open, low (6 blend variants, smoothing, push-out, rebind all failed) |
| `black\|hispanic\|southeast-asian.female.adult.*.base.face-side.rest` | small lit patch at the very front of the lower lip (close profile) | fixed c247e31 (CLOSE_FRONT cap), installed; black: faint seam strip in close profile, check on device |

## Open (sweep 2026-10-14)

| Cells | Issue | State |
|---|---|---|
| `*.female.adult.*.*-XXL.left\|right\|front-3q-*.rest\|back-*` | sharp diagonal crease at the waist side above the hip bone, XXL hips only, strongest at back-60 (sweep3 /tmp/sweep3/crops/xx-white-back-60-left-flank.png) | fixed f282694 (fair_flank on hips-*), c31cf5c; installed phone. Check S-XXL sitting hip-front edge |
| `*.female.adult.*.*.top-down.*` | 3-4 ridges on the inner thigh (base mesh, all hips) | fixed a96ae01 (HIP_SCALE, THIGH_PULL), daa3c5d, installed. Soft diagonal shade on upper inner thigh left |
| `*.female.adult.*.*.back.back-60+shoulder-90` | bright vertical knob where the arm meets the back | fixed (Swift: exact chord Jacobian normals + band normal smoothing, uncommitted); installed phone |
| `*.female.adult.*.*.front-3q-left.back-60+shoulder-90` | lumpy chest/rib shading under the raised arm, sharp front-armpit line | fixed (same change); shoulder-45 arm normal error up slightly (11.7 -> 17.4 p90) |
| `*.female.adult.bare.*.left\|front-3q-*.rest` | faint horizontal step across mid-thigh (KNEE_REFINE band edge) | fixed (cause: HIP_REFINE row-divided Laplacian at band edge); faint knee-band edge (-0.52) left. Also moves male/child legs (max ~10 mm) |
| `*.female.adult.dressed.XXL-XXL.back\|top-down.shoulder-160` | bra strap edge ripple near armpit | fixed (Swift: smoothed garment slide + closest-triangle garment follow, uncommitted), installed. verified (gfol): non-shoulder poses byte-identical, briefs unchanged, bra clip better at 90; ml-ea 160 'clip' is a depthNormal metric artefact (true signed distance: 0 inside, min gap 0.7 -> 1.7 mm) |
| `*.female.adult.*.*.*.elbow-145` | thin lit line at the inner crease end (no contact occlusion; 25% fewer bright px after refine) | fixed: contact-shade overlay (Swift, uncommitted); check on device incl. elbow-90 dimple, overlay flicker, glass-skin view |
| `*.female.adult.*.*.*.knee-135` | bright sliver in the knee pit (~115 px in pit close-up) | fixed: contact shade + sideKeep normals (uncommitted), installed |
| `*.female.adult.*.*.side\|back-3q-*.shoulder-160` | back of shoulder still a rounded bump; faint diagonal crease on the back armpit fold; shoulder relax frame time unchecked on device | fixed (Swift: convex cut fades behind the pivot, uncommitted), installed. Perf: bendSkin 11 -> 6.5 ms (M1, output identical), unmeasured on iPhone |
| `*.female.adult.dressed.M-XL\|XXL.*.*` | bra-medium on wide hips still creases (162 edges); bra-xlarge small cluster below the nipple | fixed ef04b92/8ea3244, installed. Left: small dense patch above the nipple on bra-xlarge/xxlarge |
| `*.female.adult.*.*.*.knee-135` | front-of-knee stretch (218 edges >2), small notch in the knee pit; thin bright sliver in inner elbow crease | fixed (Swift, uncommitted), installed. Left: elbow-145 sliver, faceted knee front outline at 135 |
| `*.female.adult.*.XXL-XXL.back\|left.back-*` | second dip at the fullest point of large buttocks (hip pivot far from the skin) | halved (Swift BackBend raise, uncommitted), installed |
| `*.female.adult.*.*.top-down.elbow-*` | forearm outline beyond the refined band still coarse | fixed f38ba3f (FOREARM_REFINE, ELBOW_FRONT_REFINE, 2nd KNEE_REFINE; +4296 tris) |
| `*.female.adult.dressed.M-*.*.low-up.*` | faint shading lumps where the cup meets the band; small band-edge kink at the side | fixed 148c59c (BAND_SHEET, CUP_RELAX, front panel stops inside band) |
| `*.male\|child.*.*.*.shoulder-*` | back-armpit slit (fix applied to the woman only) | waits |

## In progress

- none

## Log

- 2026-10-20: posture sitting bra: strap crest stood 8.8 mm off the shoulder (cut's clearance push spread over the strap width) -> eased to lift in posture bins (3.6-5.1 mm); slouched cup-sheet ripple from single small anchor triangles -> wide skin triangles (rest look 0.000 mm). Female bra clip 0 on all 8 bins (min gap phone-standing 0.61 -> 0.35 mm), bodies byte-equal except arm press (phone-standing XXL <=1 mm, pregnant phone-bed arm re-pick); sitting.bin +79 KB. Bins repacked in worktree, not pushed/installed.

- 2026-10-18: seated briefs hem and crease fixed in posture_rig (all 8 posture bins, models pushed, installed). All agents stopped.

- 2026-10-18: all Swift committed (8b24d6d, d7cb566), hourly QA schedule cancelled on user request; long-hair turn installed. Hispanic slouched ruff (head tipped back) left open: turning pushes hair into the back.

- 2026-10-18: sample round 6: white back-90 clean (bra +2.2, briefs +1.1 mm); posture slouched hair ruff fixed (Swift); briefs hem notches fixed (5f9cddd, models pushed). Installed.

- 2026-10-17: sample round 5: knee-135 XL and low-up back-30 clean. Posture port (tools/qa/posture_obj.py) added; posture hair bulb and skin shading fixed in PostureScene. Installed.

- 2026-10-17: repo cleanup: 82 finished agent worktrees + branches removed (42 GB -> 1.8 GB), wip-* repointed to rewritten origin, `models` tag moved to master (local + GitHub); .git 764 MB -> 18 MB.

- 2026-10-17: hinge normals turned by R only, ignoring the share gradient; foldNormal applies the exact Jacobian inside the closing bend (knee 69-86, elbow 109-135 deg, flexor side, guarded). Elbow tick and knee-90 speck/smudge reduced; positions unchanged, clipping 0. Installed.

- 2026-10-17: hair: curly hem needles rounded (tip_round), coily fold/pit closed; only those two hair pieces changed (figure.bin e696eeaa); postures carry no hair. Sculpts copied to build/models/figure + backup. Installed.

- 2026-10-17: phone back; installed all pending (bra strap/band models, armpit ridge, back armpit, back-light mask, kneeOpen). Sample round 4: back-60 XXL and elbow-145 clean of clipping; knee-90 side-shade streaks fixed.

- 2026-10-17: sternum/navel/collar/nape specks are back-light (fill -3,2,-4 / rim 1.5,3,-5, no shadows) glints on skin the body or hair should shade; mesh clean. body_backlit_mask over 24 yaws x 6 heritages x chests, 4 soft zones, into skin-seam.png (82d9d47). Pushed c9214be; phone unavailable.

- 2026-10-17: back armpit: s90 fold from the arm share clipping at 1 across 3-6 cm edges -> share reach 1.25x band + smooth ease into 1; s160 diagonal crease from the 10% convex leak sinking coarse skin -> leak scaled by (0.04/h)^2. Inner-arm sag stays fixed; clipping 0; non-shoulder byte-identical. Phone unavailable.

- 2026-10-17: sample round 3: XXL-S back-30 and M-XL back-30 clean, no clipping. Front-armpit ridge at s160 softened (relax may flatten a vertex pulled in alone). New model-side specks listed (sternum, navel rim, collarbone, nape). Phone unavailable: strap/band models + ridge Swift await install.

- 2026-10-17: bra strap spikes came from the clearance push spread over 10 rings of <1 mm slivers; spread_push over 2 cm. XXL band sag on S/M hips levelled in the hips deltas. Clipping 0 in 42 checks; all 8 postures repacked. Models pushed (5270132); phone unavailable, installed.

- 2026-10-17: shoulder top at 160: chord blend pulls skin toward the pivot + relax drags it to the armpit. shoulderTop gives back 1.5x the lost axis distance over the top (eased 60-160 deg; garments take their skin's weight). Median area 0.33 -> 0.40, strap tip crease p99 58 -> 53 deg; no clipping; non-shoulder byte-identical. Installed.

- 2026-10-17: sample round 2: face-front knee-90, top-down elbow-90 clean, no clipping. Shoulder far-share fade: upper-back drop at s90 35 -> 6 mm, strap crumple edges 487 -> 0, hair re-hidden at neck (61 -> 210 of 213), sharp folds s160 22 -> 0. Installed.

- 2026-10-17: knee-135 crease end: pressed() flattens each side; calf section 10-11.6 cm vs thigh 8-9.3 cm overhung. kneeRim (after contactShade) remaps lateral/medial extents near the plane to the two sides' mean: overhang 13.9 -> 6.3 mm; knee-90 ~unchanged; rest/elbow byte-identical. Installed.

- 2026-10-17: inner-arm relabel: torso-held skin >0.14 below the shoulder pivot, within 0.11 of the humerus, normal facing away -> arm. s90 inner-arm lag mean 36 -> 3 mm, arm edges >1.5x 779 -> 16; armpit back-fold edges >1.5x 81 -> 126 (short, no tearing). Non-shoulder poses byte-identical. Installed.

- 2026-10-17: XXL knee/elbow max + low-up QA: low-up rest S-S/XXL clean (no thigh ridges, no clipping). Contact shade now needs the other limb within 15-37 mm (grid-hash contactShade); open-skin shaded verts elbow 31 -> 2, crease shade kept. Installed.

- 2026-10-17: shoulder QA with the new port: no clipping (bra gap 1.5-1.8 mm), no armpit sheets. Back strap ripple fixed by wrapGarment (garment rides its skin behind the shoulder; wave >0.5 mm verts 136 -> 25 at 160); shoulder top squash at 160 median area 0.26 (hidden). Installed.

- 2026-10-17: posture bra_clear (b1ab6c9): couch straight arm sank 1.5-3 cm through the breast side; hand moved back on the thigh (~6 cm) + elbow pole; laptop/computer elbows out (<=5 cm). Bra clip 0 in every female posture cell (medium hips); briefs unchanged. Installed.

- 2026-10-17: tools/qa/pose.py now follows Swift bendSkin for adult women (shoulder bands, hinge press, contact shade; render.py draws shade). shoulder-160 black L-S stretch max 40.9 -> 10.1. Noted: back bra strap edge slightly wavy at shoulder-160.

- 2026-10-17: sample round. Hair groove at chin height (6-NN follow jumps jaw->neck) eased: follow_eased x40 (0b55060), strained hair edges e.g. hispanic 422 -> 28, black 1560 -> 236, no new clipping; installed. back-60 crease was a QA-port artefact: pose.py now has BackBend + neckShare (shoulder bands still missing). south-asian XXL back-60 clean.

- 2026-10-17: lower-lip front peak (close_lips lifted verts ahead of the upper lip into its curl) capped by CLOSE_FRONT (black keeps half lift); TUCK_LOWER removed, black lower lip fuller. Lower lip ahead of upper: black 71.6 -> 57, SE-Asian 117.7 -> 52.1, hispanic 59.2 -> 51.4 mm2; other heritages byte-identical. Note: tools/qa/render.py ignores skin-seam.png (agent's patched copy in its .scratch/qa).

- 2026-10-17: posture arm press (a2dae86, e078d81): arm skin pushed out past bra/briefs per key/option, kept if >=80% contacts cleared; phone-bed fit clears the XXL bra. laptop L/M, sitting XL, phone-bed XL/XXL, phone-standing XXL bra clips -> 0. Pregnant bump line not reproduced (pregnant bra clips come from the rest figure). Installed.

- 2026-10-17: paused 17:46-02:07 on user request (CPU); App Store build 202610170048 cut from 7224bbf (all Swift committed). Posture clipping agent resumed; lower-lip agent started.

- 2026-10-16: lower-lid rim seated on the ball (SEAT_RIM 1.01 radii, two passes; rim standoff ~2 -> 0.15 mm, visible ledge from top ~110 -> ~23 mm2) and CLOSE_LIPS reach 0.003 -> 0.006 closes the profile slit; 4b36672 + figure.bin, installed.

- 2026-10-16: recovery done: female-adult raws regenerated + `align` (refit renumbered 5223 chest verts; UV remap), woman-only pack reproduces shipped bodies 0.000 mm; strap cut fix shipped (worst notch 3.3 -> 2.1 mm, slits gone); posture bins rebuilt (shipped ones came from misnumbered raws, hips off up to 30 mm). QA tools now in tools/qa (pose.py, render.py, sd.py, README). Other groups' raws absent: refit + align before packing them.

- 2026-10-16: posture screens follow profile; woman + pregnant in all 8 bins, arms/props fitted (phone-standing XXL bra clip 956 -> 0). Left: laptop L/M bra 515 at last key, phone-bed XXL bra ~235, seated briefs 300-680, pregnant XXL bra ~870 at rest.
- 2026-10-16: bra strap notch over shoulders fixed in cut (CUT_RINGS, d43ee7a), spikes XXL 17 -> 1; repack pending. M-L rest 3q clean.
- 2026-10-16: /tmp and build/ wiped by an outside cleanup; raw fit data and QA tools lost. Model binaries moved out of git (release "models", assets.sha256); history stripped 843 -> 18 MB.

- 2026-10-16: elbow-90 medial dimple: contact shade scaled by (1-side), spikes 3 -> 1. Neck-70 (adult woman): neckShare band tilted along the jaw, face drift 0.110 -> 0, chin/mouth turn 37/61 -> 70/70 deg; neck edges >1.5x 0 -> 104 (smooth in renders). Left: lateral elbow crease-end shade spot; men/children keep old neck band. Swift uncommitted, installed.

- 2026-10-16: sitting: groin weights diffused (spread_groin), self-intersecting groin tris S-XXL 143 -> 47 upright, 42 -> 5 slouched; all bra cuts packed + per-chest pick (Swift PostureScene, uncommitted); briefs clip rise was noise. Left: gusset bunching at seat, XXL bra band wavy top-down, upright briefs leg-edge clip 262 -> 549 (hidden). App posture screen still shows only the male figure (PostureScreen female: false).

- 2026-10-16: nose-side / under-eye back-light glint damped via skin-seam.png backlit mask (92cacb1); pale px low-up 0:-30 69877 -> 17853, front 6067 -> 885. Left: fainter wedge at 0:-40 on dark skin, forehead/crown sheen.

- 2026-10-16: low-up lid 'sliver' is skin rim lit by back light (no shadows), not eyeball; LIFT_LIDS closes the strip. Nose-side sheen from below spotted on the same sheets.

- 2026-10-16: knee-135 pit wedge fixed (pressed side skin keeps own normal, sideKeep 0.4-0.9), pale px 650-1018 -> 0; knee band ends eased (kneeEase 0.3) band-end fold 29.5 -> 10.7 deg. Left: thin rim-light streak along crease at low back-3q; knee-90 stretch 32 edges >1.6x. Port /tmp/kp/tools/pose.py.

- 2026-10-16: bendSkin perf (packed neighbours, scratch buffers, pose cache) 40-65% faster, bit-identical; bench /tmp/perf/bench.sh. bindSkin holder votes now tie-break by key: hand vertices no longer jump per launch (was up to 1.1 at elbow-145).

- 2026-10-16: garment follow verified; depthNormal clip metric over-reports on curved coarse back (use true signed distance, /tmp/gfol/tools/sd.py).

- 2026-10-16: thigh band-zone bend p99 36 -> 25.5, inner-thigh ridges evened; knee-90 folds 12 -> 4; sitting briefs clip +2-8% (noise?).

- 2026-10-16: shoulder normal smoothing now 45-90 deg (shoulder-45 arm error 17.4 -> 3.1); strap flipped faces at 160 33 -> 6; garments bind to closest skin triangle (3 weights) instead of 8 nearest vertices. No shading pop 0-90.

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
| 2026-10-16 | `*.female.adult.*.base.top-down\|front-3q-*\|face-side.rest` | lower-lid grey/pink rim (rim stood 1.4–2.3 mm off the ball) seated; lip slit in profile closed | 4b36672, repack |
| 2026-10-15 | `*.female.adult.*.*.back\|left.back-*` | hip share fades out higher (hipBandUp 0.30), into the spine curve: shelf dip 122–158→20–40 °/m (XXL 148→100) | uncommitted |
