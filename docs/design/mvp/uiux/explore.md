# Explore

Category grid. First tab, app home. Code: `Sources/Screens/ExploreView.swift`.

```
 Explore
 ──────────────────────────────────────────────────────
 ┌────────────────────────────────────────────────────┐
 │ 🔍 Search parts, points, systems                   │  ← tap → Search sheet
 └────────────────────────────────────────────────────┘
 ┌────────────────┬────────────────┬────────────────┐
 │   (skull img)  │  (muscle img)  │  (brain img)   │
 │                │                │                │
 │ Skeleton       │ Muscles        │ Brain          │
 ├────────────────┼────────────────┼────────────────┤
 │ Heart          │ Organs         │ Circulation    │
 ├────────────────┼────────────────┼────────────────┤
 │ Nerves         │ Digestion      │ Reflex Map     │  ← 穴位反射图
 ├────────────────┼────────────────┼────────────────┤
 │ Hand           │ Foot           │ Ear            │
 └────────────────┴────────────────┴────────────────┘
 ──────────────────────────────────────────────────────
     ◉ Explore                    ⚙ Settings
```
Scrolls: below the grid sits the ILLUSTRATIONS · 图解 section → `illustrations.md`.

Tile = thumbnail (rendered from the model, static PNG) + label. Square, 3 columns at
every phone width. Label under names setting "Both": `Skeleton` / `骨骼` on two lines.

Tile → Viewer preset:

| Tile | Systems shown | Focus |
|---|---|---|
| Skeleton / Muscles / Organs / Nerves / Digestion / Circulation | that system | full body |
| Brain / Heart | nervous / circulatory + organs | head / chest |
| Hand / Foot / Ear | skeletal + muscular | region |
| Reflex Map | skin + reflex points | full body, Points sheet open |

Reached from: launch · tab bar.

## States

```
first-run   same grid; no onboarding here (hint lives in Viewer)
longest     │ Circulation    │   ← labels fit; 中文 ≤ 5 chars
            │ 循环系统       │
```
Only one state otherwise — all data is bundled.

## Interactions

| Target | Action | Result |
|---|---|---|
| search field | tap | Search sheet, keyboard up |
| tile | tap | → Viewer with preset |

## Copy

| Key | String |
|---|---|
| `explore.title` | Explore |
| `explore.search` | Search parts, points, systems |

## Notes

Male / Female tiles hidden until the schematic female variant (T10.2) exists — no "coming soon"
tiles.
