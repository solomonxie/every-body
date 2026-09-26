# Part info

Stack page. From Part card Details › / drag ▲, or Viewer ⓘ (system-level).
Code: `src/app/info/[id].tsx`.

```
 ‹ Skeleton             Femur
 ──────────────────────────────────────────────────────
 ┌────────────────────────────────────────────────────┐
 │            (static render of femur, isolated)      │
 └────────────────────────────────────────────────────┘
 Femur
 股骨 · gǔ gǔ
 Skeletal · Lower limb

 The longest and strongest bone in the body, running
 from hip to knee.

 ╭──────────────────────────────────────────────────╮
 │ Connects to              Hip bone, Patella, Tibia│
 ├──────────────────────────────────────────────────┤
 │ Muscles attached                             (23)›│
 ╰──────────────────────────────────────────────────╯
 RELATED
 ( Hip bone ) ( Patella ) ( Tibia ) ( Femoral artery )

              [[ Show on model ]]
```

Reflex point variant: adds LOCATION and ACTS ON rows + claim line (see `points.md`).
System variant (Viewer ⓘ): no Connects rows; lists sub-regions.

## States

```
no description   Femur / 股骨 / Skeletal · Lower limb
                 No description yet.
unknown id       ⚠ Part not found.   ‹ back
```

## Interactions

| Target | Action | Result |
|---|---|---|
| related chip | tap | push Part info for that part |
| Muscles attached | tap | list page of parts |
| Show on model | tap | pop to Viewer, focus + select part |

## Copy

| Key | String |
|---|---|
| `info.showOnModel` | Show on model |
| `info.related` | Related |
| `info.noDescription` | No description yet. |
| `info.notFound` | Part not found. |
