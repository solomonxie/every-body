# Viewer

Full-bleed 3D model with edge rails. Reached from Explore tiles, Search, Part info.
Code: `src/app/viewer/[id].tsx`.

```
 ‹ Explore           Skeleton
┌──────────────────────────────────────────────────────┐
│ 🔍                                                 ↶ │ ← Undo; · when stack empty
│                         ___                          │
│ Layers                 (   )                       ◐ │ ← background gray ⇄ white
│                         \_/                          │
│ Display               /|   |\                      ⌂ │ ← reset camera
│                      / |   | \                       │
│ ⓘ                      |   |                         │
│                        /   \                         │
│ Quiz·                 /     \                        │ ← post-v1, hidden in v1
│                                                      │
└──────────────────────────────────────────────────────┘
  left rail: 🔍 Search · Layers · Display · ⓘ system info
```

Rail buttons: 44 pt, translucent chip, icon only with accessibility label. Rails float
over the canvas; the canvas spans behind them.

## Gestures

```
drag 1 finger     rotate (orbit around focus)
pinch             zoom, clamped
drag 2 fingers    pan
tap part          select → Part card
tap empty         deselect
double-tap part   focus camera on part
double-tap empty  reset camera (= ⌂)
```
Auto-rotate (setting, default on) runs until the first touch, never resumes that visit.

## Part card

```
            tap femur ↓
┌──────────────────────────────────────────────────────┐
│                     (femur tinted accent)            │
│                                                      │
│▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁│
│ Femur · 股骨                                      ✕ │
│ Skeletal · Lower limb                                │
│ [ Hide ]  [ Isolate ]  [ Fade ]         Details ›    │
└──────────────────────────────────────────────────────┘
```
- Peek height only; drag ▲ → Part info page (same as Details ›).
- Hide / Isolate / Fade each push one Undo step.
- Long name: `Flexor digitorum superficialis · 指浅屈肌` wraps to 2 lines, then `…`.

### Try on a part

Part card gains a `Try` action when the part has a mechanism:

```
│ Elbow joint · 肘关节                              ✕ │
│ Skeletal · Upper limb                                │
│ [ Hide ]  [ Isolate ]  [ Try ▸ ]        Details ›    │
            Try ▸ ↓
│ Drag the forearm ▲▼    flexion ├────●──┤ 90°          │
│ Biceps contracting · triceps relaxed                  │ ← muscles tint live
```
Try kinds on parts: joint range of motion (drag), muscle contract (drag), heart beat
(scrub rate), lungs breathe (scrub rate), stomach digestion (scrub time).

## Layers sheet

Built first as a pill bar at the top of the panel (`皮肤 Skin · 肌肉 Muscles · 骨骼 Bones · 血管 Vessels · 神经 Nerves · 器官 Organs`,
multi-select, + `Show all (n hidden)`); the sheet below adds opacity sliders later.

```
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
 LAYERS                                      Show all
 Skin          ○─   ├●───────────────────┤   0%
 Muscular      ─●   ├──────────────●─────┤  70%
 Circulatory   ─●   ├────────────────────●┤ 100%
 Nervous       ○─   ├────────────────────●┤ 100%·   ← slider · while layer off
 Organs        ─●   ├────────────────────●┤ 100%
 Digestive     ○─   ├────────────────────●┤ 100%·
 Skeletal      ─●   ├────────────────────●┤ 100%
 ──────────────────────────────────────────────────
 OVERLAYS
 Reflex points                                  ○─
 Blood flow                                     ─●
```
Order outer → inner, so "peeling" = working down the list. Changes are live; one Undo
step per toggle / per slider release. No Done button — drag ▼ or tap canvas to close.

## Display sheet

```
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
 DISPLAY
 Part labels on model                           ○─
 Names          [ English | 中文 | BOTH ]              ← same value as Settings
 Background     [ GRAY | White ]
 Auto-rotate on open                            ─●
```

## States

```
loading     ⟳ Loading Skeleton…   [██████░░░░] 60%       rails hidden
error       ⚠ Couldn't load Muscles.        [ Retry ]
no GL       ⚠ 3D isn't supported on this device.
            Explore still works; the model can't be shown.
all hidden  All layers are hidden.          [ Show all ]  centered over empty canvas
first-run   ⌐ Drag to spin · pinch to zoom · tap a part ¬
            ← once ever, dismissed by first touch
undo empty  ↶·
```

## Interactions

| Target | Action | Result |
|---|---|---|
| 🔍 | tap | Search sheet, scoped to this system first |
| Layers | tap | Layers sheet |
| Display | tap | Display sheet |
| ⓘ | tap | Part info for the system itself |
| ↶ | tap | undo last hide/isolate/fade/layer change |
| ◐ | tap | toggle gray/white background (persists) |
| ⌂ | tap | reset camera + clear isolate |
| ‹ | tap | back; viewer state not kept |

## Copy

| Key | String |
|---|---|
| `viewer.loading` | Loading {system}… |
| `viewer.error` | Couldn't load {system}. |
| `viewer.retry` | Retry |
| `viewer.noGl` | 3D isn't supported on this device. |
| `viewer.allHidden` | All layers are hidden. |
| `viewer.showAll` | Show all |
| `viewer.hint` | Drag to spin · pinch to zoom · tap a part |
| `part.hide` / `isolate` / `fade` | Hide / Isolate / Fade |
| `part.details` | Details |

## Notes

✗ Persistent layer sidebar (current placeholder has a slider panel) — steals width from
the model on phones; replaced by the Layers sheet.
