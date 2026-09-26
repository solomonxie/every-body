# Points sheet — Reflex Map & Blood flow

Persistent bottom sheet on the Viewer when the system has points
(`POINTS_BY_SYSTEM`). Code: `Sources/Body/BodyScene.swift` (pulse), `Sources/Charts/`, data `Resources/Data/points.json`.

## Reflex Map

```
 ‹ Explore        Reflex Map
┌──────────────────────────────────────────────────────┐
│ 🔍                  (body, skin)                   ↶ │
│ Layers                  •  ← Baihui               ◐ │
│ Display          •            •   ← dots = points   ⌂ │
│ ⓘ                     •                              │
│                    •     •                           │
│▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁│
│ [ ALL | Foot | Hand | Ear | Body ]                    │
│ ( Head/Brain (Foot) ) ( Kidney (Foot) ) ( Liver… )  →│ ← chips scroll
│ Press a point — watch where it acts.                 │
└──────────────────────────────────────────────────────┘
```
Filter changes the camera focus too (Foot → feet, Ear → head side).

### Press sequence

```
t=0 tap ↓              t≈0.7 s                 t=1.4 s → 2.2 s
┌──────────────┐      ┌──────────────┐        ┌──────────────┐
│      ◯ kidney│      │      ◯       │        │     (◉) ✦    │ ← target flashes
│              │      │     ·•       │        │              │
│              │      │   ·          │        │              │
│  ◉ sole      │      │  ◉           │        │  ◉           │
└──────────────┘      └──────────────┘        └──────────────┘
  dot glows,           pulse travels            effect card appears ↓
  camera eases to      along surface
  frame both
```

### Effect card

```
 ╭──────────────────────────────────────────────────╮
 │ Kidney Reflex Zone (Foot) · 肾反射区(足)          │
 │ Center of the sole.                              │
 ├──────────────────────────────────────────────────┤
 │ → Kidneys · 肾                                   │
 │ Stimulates kidney filtration, relieves           │
 │ lower-back tension.                              │
 │ 促进肾脏排毒，缓解腰部紧张。                      │  ← only when names = Both/中文
 │ Traditional reflexology claim. ⓘ                 │  ← ⓘ → disclaimer popover
 ╰──────────────────────────────────────────────────╯
                                         ( Replay )
```
Card fades in only after the target flash — the effect "lands" with the animation.

## Hand, foot & ear charts

Stack page — from Explore tiles, or Reflex Map › Foot/Hand/Ear filter › "Open … chart".
Layout button [▤] in the controls row (remembered): **Up/down** (default, drawn below),
**Left/right** (chart left, body right), **Body + chart box** (full body, chart in a
bottom-right box ≈ 46 %). Split layouts have a draggable bar (body 15–80 %). Each half
pinch-zooms on its own and starts fitted. Zones carry no labels; names live in a list below,
linked both ways.

```
 ‹ Back          Hand reflex zones           [👤 Adult M ▾]
 [ Left | RIGHT ]  [ PALM | Back ]
┌──────────────────────────────────────────────────┐
│          Kidney → Left kidney, Right kidney      │ ← caption
│                        ◯                         │
│                       /█\   ✦ lit organ          │  3D body ≈ 42 %
│                        █    1 finger spin, pinch │
│                       ▐ ▌                        │
└──────────────────────────────────────────────────┘
                     ━━━━━━  ← drag to resize
┌──────────────────────────────────────────────────┐
│        ___ ___         ┌──────┐                  │
│       |   |   |        │Kidney│ ← tag on selected │  chart, pinch + pan
│      (  ◯   ◯  )        └──◉───┘                  │  ⟲ 1× when zoomed
│        (  ◯  )   ◯                               │
└──────────────────────────────────────────────────┘
 ● Brain ● Pituitary  ● Neck   ● Eye ● Ear  ⚠ Gonads │ ← name list, 96 pt, scrolls;
 ● Lung  ◉ KIDNEY ◉   ● Bladder …                    │   tap ↔ chart both ways
├──────────────────────────────────────────────────┤
│ Kidney                                 ↻ Replay  │
│ ⚠ caution for the chosen person (if any)         │
│ Middle of the palm. …                            │
└──────────────────────────────────────────────────┘
```
- One drawing per face (left palm, back of right hand, left sole/top, left ear); the other
  side mirrors. Side-only zones (心 left / 肝 right) filter by side.
- Tap zone → others dim, pulse leaves the body's hand/foot/ear → organs light → card.
- ⟲ 1× appears only when the chart is zoomed or panned.

## Blood flow (Circulation)

```
│▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁│
│ BLOOD FLOW                              ( ❚❚ Pause ) │
│ Speed       ├──────●──────────────┤ 1×               │
│ Heart › Aorta › Arteries › Capillaries › Veins › …  →│ ← current stop bold
│ Heart · 心脏                                          │
│ Pumps blood into the circulatory loop.               │
└──────────────────────────────────────────────────────┘
```
Try: `Heart rate ├──●──┤ 72 bpm` slider (scrub) speeds flow + beat;
`⊙ Follow a blood cell` (follow) rides one particle round the loop.
Particles: red leaving heart, shifting blue after capillaries. Tap a stop → pause there,
show its card.

## States

```
mid-pulse tap   new point restarts the sequence; old card hidden
no target       point without target: glow + card, no pulse
overlay off     Layers › Reflex points off → dots hidden, sheet collapses to chips
reduce motion   pulse replaced by instant target flash; flow shows static arrows
```

## Copy

| Key | String |
|---|---|
| `points.hint.reflex` | Press a point — watch where it acts. |
| `points.claim` | Traditional reflexology claim. |
| `points.claim.info` | Based on traditional Chinese medicine and reflexology. Not medical advice — see a clinician for health concerns. |
| `points.replay` | Replay |
| `flow.title` | Blood flow |
| `flow.pause` / `flow.play` | Pause / Play |
