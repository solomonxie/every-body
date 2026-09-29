# Third-party assets

Third-party material: the files in `Resources/Models/` (built by `scripts/models/build.sh`) and the scene pictures in
`Resources/Illustrations/` (built by `scripts/art3d/build.sh`).

## Skeleton — Z-Anatomy (CC BY-SA 4.0)

- File: `Resources/Models/skeleton.usdz` (and the `skeleton` entries of `models.json`)
- Source: "Z-Anatomy – The libre 3D atlas of anatomy", `Z-Anatomy.zip` / `Startup.blend`,
  https://github.com/Z-Anatomy/Models-of-human-anatomy
- Authors: Gauthier Kervyn (design, 3D, anatomy), Marcin Zielinski (Blender add-on), Lluis Vinent, and translators listed in the source.
- Attribution requested by the authors:
  - **"Z-Anatomy - The libre 3D atlas of anatomy - CC-BY-SA 4.0"**
  - **"BodyParts3D, © The Database Center for Life Science licensed under CC Attribution-Share Alike 2.1 Japan"**
    (Kousaku Okubo; https://dbarchive.biosciencedbc.jp/en/bodyparts3d/)
- Licence: https://creativecommons.org/licenses/by-sa/4.0/
- Changes: only skeletal-system meshes plus intervertebral discs, menisci and the interpubic disc; objects
  renamed to this app's ids, small bones merged (carpals, finger/toe phalanges, teeth, sternum, ossicles),
  decimated to ~138k triangles, and warped piecewise (per limb segment, trunk heights) onto this app's body landmarks.
  Parts Z-Anatomy marks as non-commercial (inner ear, kidney) are **not** used.
- **The adapted model files in `Resources/Models/skeleton.usdz` are released under CC BY-SA 4.0.**

## Muscles, organs, vessels, nerves — Z-Anatomy (CC BY-SA 4.0)

- Files: `Resources/Models/muscles.usdz`, `organs.usdz`, `vessels.usdz`, `nerves.usdz` (and `internals` in `models.json`)
- Source, authors and attribution: as for the skeleton above (same `Startup.blend`). Z-Anatomy also credits, for parts used here:
  - brain surface: "Brainder" (Anderson M. Winkler, https://brainder.org, CC BY-SA 3.0) and "White matter" (University of Washington);
    only the cortex, cerebellum and brainstem surfaces are used, no white-matter model;
  - cranial nerves: **"Cranial Nerves and Foramina - by University of Dundee, CAHID - CC-BY 4.0"**.
- Changes (`scripts/models/build_internals.py`): objects renamed to this app's ids, merged per muscle / organ / vessel group,
  muscles and organs decimated (brain voxel-remeshed first), vessels and nerves re-meshed as thin tubes, warped onto the fitted
  skeleton, muscles pulled under the skin figures (plus a female-fitted copy), fibre UVs added.
- **Not used**, because Z-Anatomy marks them non-commercial: the kidney (Lissie Cowley, CC BY-NC 4.0) incl. renal pelvis,
  intrarenal vessels and suprarenal glands, and the inner ear (University of Dundee, CC BY-NC-SA 4.0). The app keeps its own
  generated kidneys, adrenals and ears.
- **The adapted model files are released under CC BY-SA 4.0.**

## Skin figures — MakeHuman via MPFB2 (CC0 1.0)

- Files: `Resources/Models/figure.bin` (meshes), `skin-<heritage>-<male|female>-<young|old>.jpg`, `skin-<heritage>-kid.jpg`,
  `hair-*.jpg/png`, `brows-*`, `lashes-*`, `eyes.jpg`, `fabric.png` (built by `scripts/models/build_figure.py`)
- Made headless with MPFB 2.0.17 (https://github.com/makehumancommunity/mpfb2) in Blender 4.5 LTS.
- Assets: MakeHuman base mesh and targets — macros (sex, age, race, muscle, weight, proportions, cup size), torso,
  hip, buttocks, `stomach-pregnant` / `stomach-navel` and face targets (head, forehead, eyebrows, eyes, nose, mouth, cheek,
  chin, neck; bundled with MPFB, CC0 per `LICENSE.ASSETS.md`), and
  `makehuman_system_assets` (CC0, https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html):
  skins `young_*` / `old_*` × `asian` / `caucasian` / `african` × `male` / `female`, eyes `low-poly` + `brown`,
  eyebrows `eyebrow006` / `eyebrow010` / `eyebrow012`, eyelashes `eyelashes01` / `02` / `03`,
  hair `short01` / `short04` / `long01` / `ponytail01`.
- Licence: CC0 1.0 (public domain dedication), https://creativecommons.org/publicdomain/zero/1.0/ — no attribution required; credited anyway.
- Changes: posed into the anatomical position and fitted to the app's landmarks (children to the app's age proportions);
  face targets per sex and heritage; heritage limited to the head; Southeast Asian, South Asian and Hispanic skins are
  pixel blends of the Asian, African and Caucasian skins; chest marks toned; scalp under the hair tinted
  with the hair colour; hair and brows reduced to grey strands and tinted per heritage (silver for 65+); pregnant bump
  scaled to term; textures resized/recompressed, iris toned; underwear cut from the base mesh by the app's pipeline
  (no third-party garment).

## Faces and hair — Blender Studio Snow and Rain (CC BY 4.0)

- "Snow Rig © Blender Foundation | studio.blender.org" (https://studio.blender.org/characters/snow/v2/) and
  "Rain Rig © Blender Foundation | studio.blender.org" (https://studio.blender.org/characters/rain/v2/), CC BY.
- Used: the heads (Snow for men, Rain for women and children), their eye centres and sculpted hair (Snow's; Rain's main hair
  and ponytail, bent to hang). `scripts/models/face_fit.py` draws each MakeHuman figure's face onto the head (matched by
  478 face landmarks, blended part way for adults) and carries the hair onto it; the figure keeps its own mesh, UVs and
  skin. No rig, texture or material of theirs ships.

## Scene pictures — MakeHuman via MPFB2 (CC0 1.0)

- Files: `Resources/Illustrations/<scene>/*.webp` — CPR, choking, recovery position, severe bleeding, stroke, heart attack,
  pregnancy warning signs, morning sickness, sleeping position (built by `scripts/art3d/build.sh`: `render.py` + `pack.py`)
- Made headless with MPFB 2.0.17 in Blender 4.5 LTS (EEVEE render); same source and licence as the skin figures above.
- Assets (`makehuman_system_assets`, CC0): base mesh, macro and `stomach-pregnant` / `stomach-navel` targets, the `default` rig,
  eyes `low-poly`, eyebrows `eyebrow006` / `010` / `012`, eyelashes `eyelashes01` / `02` / `03`,
  hair `bob02` / `short02` / `short03` / `short04`, clothes `female_casualsuit01` / `02`, `female_sportsuit01`,
  `male_casualsuit04` / `06`, shoes `shoes02` / `03` / `05` / `06`; skin, clothes and hair textures kept only as shading detail.
- Changes: posed per step, recoloured, garments cut (top off or cut open, trouser leg rolled up, socks removed; a sports-bra
  band, gloves and a blanket cut from the skin mesh); props (AED, pads, phone, table, chair, bed, bandage, tourniquet)
  modelled in the scripts.
- Licence: CC0 1.0 (public domain dedication), https://creativecommons.org/publicdomain/zero/1.0/ — no attribution required; credited anyway.

## Tools

- Blender 4.5 LTS (GPL) and the MPFB2 add-on (GPL code) were used as tools only; no code from them ships in the app.
