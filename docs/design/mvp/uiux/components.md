# Components

Parts used on 2+ surfaces. Code: `Sources/Common/`, `Sources/Viewer/ViewerPanels.swift`.

## RailButton

```
 ┌────┐   ┌────┐   ┌────┐
 │ 🔍 │   │ ↶  │   │ ↶  │·
 └────┘   └────┘   └────┘
 default  pressed   disabled      44×44 pt, translucent bg, a11y label required
          (bg +10%)
```
Props: `icon`, `label`, `onPress`, `disabled`. Used in both Viewer rails.

## CategoryTile

```
 ┌────────────────┐   ┌────────────────┐
 │  (thumbnail)   │   │  (thumbnail)   │
 │                │   │                │
 │ Skeleton       │   │ Skeleton       │
 └────────────────┘   │ 骨骼           │
   names: English     └────────────────┘  names: Both
```
Props: `category`, `onPress`. Square; label max 1 line per language.

## BilingualName

```
English   Femur
中文      股骨
Both      Femur · 股骨           inline (rows, cards)
          Femur                  stacked (titles, tiles)
          股骨
```
Props: `en`, `zh`, `layout: 'inline' | 'stacked'`. Reads the Names setting.

## PointChip

```
 ( Kidney (Foot) )   (( Kidney (Foot) ))   ( Kidney (Foot) )✦
   default            selected              pulse in flight
```

## Sheet

```
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁   grabber edge; detents: peek / half / full
 TITLE          action   ← optional right action (Show all, Pause)
```
One sheet open at a time; opening another replaces it. No backdrop dim on peek/half —
model stays interactive above.

## Toast

```
⌐ Femur hidden     ( Undo ) ¬     3 s, from Hide / Isolate
```

## TryControl

One component, six modes; step data picks the mode and binds it to a scene param.

```
scrub      Label  ├──────●────┤ value unit
drag       ( ◉ ) ──▶ ◌        in-scene handle + ghost target, no sheet control
rhythm     ◯  112/min ✓       big tap target, rate readout
hold       ◯  ▓▓▓▓░░ 7 s
compare    [ HEALTHY | Affected ]
follow     ⊙ Follow …   /  ⊗ Stop following
feedback   ✓ Back in place.   ⚠ Too fast — aim for 100–120.
```
Props: `mode`, `param`, `range | target | rate | duration`, `successWhen`, `copy`.

## ProfileMenu

Toolbar chip on every page. Code: `Sources/Common/ProfileMenu.swift`.

```
 [👤 Adult M ▾]        [🧒 Child F ▾]        [👤 Pregnant ▾]
   ╭──────────────────────────╮
   │ Age  ✓ Adult             │  Infant <1 · Toddler/child 1–12 · Adult · 65+
   │ Sex  ✓ Male              │
   │ ☐ Pregnant               │  ← Female + Adult only
   ╰──────────────────────────╯
```

Changing it rebuilds the open illustration for that person type and re-evaluates point
cautions: flagged points get ⚠ in lists and a dashed red outline on charts; the effect card
shows a red caution box.
