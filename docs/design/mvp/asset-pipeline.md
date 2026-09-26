# Asset pipeline (T3.2–T3.4, T6.3)

```
Z-Anatomy .blend ──▶ scripts/assets/export.py (Blender headless)
   │                   ├─ per system collection → <system>.glb
   │                   ├─ decimate: High 100%, Low ~30%
   │                   ├─ Draco / meshopt compress (gltf-transform)
   │                   └─ parts.json (metadata)
   └─▶ assets/models/{high,low}/<system>.glb + src/data/parts.json
```

- Source pinned by release/commit; script is the only way models change.
- Run via local `venv/` + Blender CLI; `npx gltf-transform` for compression.

## Part ids

- `id` = slugged Blender node name (`femur-l`), stable across re-exports.
- Duplicate L/R: suffix `-l` / `-r`; metadata shares one entry via `baseId`.
- A rename in the source = a migration note in the script, never a silent id change.

## Metadata

`parts.json`: `{ id, baseId, nameEn, nameZh, pinyin, system, region, parentId }`.
EN from Z-Anatomy (TA2 names); 中文 from TA Chinese edition — gaps flagged, not guessed.

## Thumbnails

Headless Blender render per Explore tile preset → `assets/images/tiles/<id>.png`, 512².

## Budget

- Total models ≤ 60 MB installed (High + Low).
- Per-system GLB ≤ 12 MB; loader memory ≤ 300 MB on Low.
- Script prints a size table; CI fails over budget.
