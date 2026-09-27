# Third-party assets

Only the files in `Resources/Models/` come from third parties. Built by `scripts/models/build.sh`.

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

- Files: `Resources/Models/figure.bin` (meshes), `skin-<heritage>-<sex>-<young|old>.jpg`, `hair-*.jpg/png`,
  `brows-*`, `lashes*`, `eyes.jpg` (built by `scripts/models/build_figure.py`)
- Made headless with MPFB 2.0.17 (https://github.com/makehumancommunity/mpfb2) in Blender 4.5 LTS.
- Assets: MakeHuman base mesh and targets — macros (sex, age, race, muscle, weight, proportions, cup size), torso,
  hip, buttocks and `stomach-pregnant` targets (bundled with MPFB, CC0 per `LICENSE.ASSETS.md`), and
  `makehuman_system_assets` (CC0, https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html):
  skins `young_*` / `old_*` × `asian` / `caucasian` / `african` × `male` / `female`, eyes `low-poly` + `brown`,
  eyebrows `eyebrow001` / `eyebrow009`, eyelashes `eyelashes01`, hair `short02` / `ponytail01` / `bob02`.
- Licence: CC0 1.0 (public domain dedication), https://creativecommons.org/publicdomain/zero/1.0/ — no attribution required; credited anyway.
- Changes: posed into the anatomical position and fitted to the app's landmarks (children to the app's age proportions);
  heritage limited to the head; Southeast Asian, South Asian and Hispanic skins are pixel blends of the Asian, African and
  Caucasian skins; hair recoloured (dark brown `bob02`, grey for 65+); textures resized/recompressed, iris toned;
  underwear cut from the base mesh by the app's pipeline (no third-party garment).

## Tools

- Blender 4.5 LTS (GPL) and the MPFB2 add-on (GPL code) were used as tools only; no code from them ships in the app.
