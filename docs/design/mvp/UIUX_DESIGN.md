# Body Atlas v1 — UI/UX

Why/scope: [DESIGN.md](DESIGN.md). Mockups: [`uiux/`](uiux/). Glyphs per the `uiux`
skill's `notation.md`; mobile mocks 60 cols.

## Screen map

```
      Launch
        │
        ▼
  ┌ Home (one page) ┐──tap tile──▶ Viewer / Chart ──ⓘ──▶ Info
  │ 🔍 search       │──results inline, same page
  │ Maps (2 rows ▾) │
  │ Illustrations ──┼──▶ Player
  │ Settings        │   (section, not a tab)
  └─────────────────┘
  every page: toolbar chip [👤 Adult M ▾] → age / sex / pregnant
```

## Principle: schematic, not lifelike

Draw with geometry — capsules, ellipses, lines, arcs, colour-coded zones. A shape only has
to be recognisable; what must be exact is *where* things are and *what connects to what*.
No photo textures, no image assets for anatomy. Allowed: tiny procedural tint patterns
(muscle fibre stripes, bone grain) that cost nothing to render.

```
✓ ( )  capsule finger, zone at the right joint      ✗ traced photo-real hand
✓ ellipse organ, labelled, lights up                ✗ textured organ model
```

## Principle: watch, then try

Every feature has an animation and an interactive control (6 shared primitives:
scrub, drag-to-target, rhythm tap, press & hold, compare, follow) —
see [illustrations.md](uiux/illustrations.md#try-primitives).

| Feature | Watch | Try |
|---|---|---|
| Parts | highlight, focus | joint ROM / muscle contract / organ rate |
| Reflex Map | pulse → target flash | press any point, compare two |
| Circulation | flow loop | heart-rate scrub, follow a cell |
| Illustrations | step animation | per-topic try step |

## Screens & surfaces

| Surface | Kind | Why this kind | Mock |
|---|---|---|---|
| Home | the only root page | search + maps + illustrations + settings in one scroll | [explore.md](uiux/explore.md) |
| Viewer | stack page, full-bleed | the model needs the whole screen | [viewer.md](uiux/viewer.md) |
| Part card | peek sheet over Viewer | keeps model visible while reading | [viewer.md](uiux/viewer.md#part-card) |
| Points sheet | persistent sheet (reflex / flow systems) | list + effect card, model stays above | [points.md](uiux/points.md) |
| Layers | sheet | per-system toggle + opacity, multi-row | [viewer.md](uiux/viewer.md#layers-sheet) |
| Display | sheet | viewer-local toggles | [viewer.md](uiux/viewer.md#display-sheet) |
| Search | inline on Home | results replace Home sections while typing | [search.md](uiux/search.md) |
| Part info | stack page | long text + related parts; own back stack | [part-info.md](uiux/part-info.md) |
| Topic list | stack page | one group's scenarios | [illustrations.md](uiux/illustrations.md#topic-list) |
| Player | Viewer in scenario mode | same canvas, rails → step controls | [illustrations.md](uiux/illustrations.md#player) |
| Settings | last Home section | few prefs; a tab for them was overhead | [settings.md](uiux/settings.md) |
| Profile chip | toolbar menu, every page | who the content is about | [components.md](uiux/components.md#profilemenu) |
| Licenses, Disclaimer | stack pages | static text | [settings.md](uiux/settings.md) |

Reusable parts: [components.md](uiux/components.md).

## Flows

```
Explore a system
  Explore ─tap "Skeleton"─▶ Viewer(skeleton, focus: full body)
    ⟳ loading ─ok─▶ model, auto-rotate until first touch
              └─fail─▶ ⚠ error ( Retry )

Identify a part
  Viewer ─tap mesh─▶ part highlighted + Part card peek
    ├─ Hide / Isolate / Fade ─▶ model updates, ↶ Undo enabled
    ├─ Details › ─▶ Part info ─Show on model─▶ Viewer (focused on part)
    └─ ✕ / tap empty space ─▶ deselect

Reflex press
  Explore ─tap "Reflex Map"─▶ Viewer + Points sheet
    tap dot on model | tap chip ─▶ dot glows ─▶ pulse travels (1.4 s)
      ─▶ target flashes (0.8 s) ─▶ effect card      ( Replay )
    tap another point mid-pulse ─▶ restarts from new point

Play an illustration
  Explore ─"First aid"─▶ Topic list ─"CPR"─▶ Player step 1
    Next ─▶ step animates (camera, layers, overlays) ─▶ … ─▶ ✓ Done ( Replay )
    tap part ─▶ pause + Part card     ‹ ─▶ Topic list

Search
  🔍 (Explore or Viewer) ─type─▶ results: PARTS · POINTS · SYSTEMS
    ├─ tap part  ─▶ Viewer(part's system) focused + Part card
    ├─ tap point ─▶ Viewer(reflex) + pulse plays
    └─ no match  ─▶ empty state, query kept
```

## Deviations from the `uiux` skill

None. Applied: explanations behind ⓘ (Settings About, reflex disclaimer); pickers in
Settings are segmented controls, not sheets.
