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
Chart and body side by side: a standing figure is tall and narrow, so a full-height pane
shows it several times larger than an inset, and both stay visible while the pulse travels.

```
 ‹ Back        手部反射区 Hand reflex zones
 [ Left 左 | RIGHT 右 ]  [ 掌 PALM | 背 Back ]  [Aa]
┌──────────────────────────────┬───────────────────┐
│    ___ ___                   │ 肾 → 左肾、右肾    │ ← caption: zone → organs
│   |鼻窦|鼻窦|  ___            │        ◯          │
│   | 眼 | 耳 | |   |          │       /█\         │
│   (    肺·支气管    ) 肩      │      / █ \        │
│  /大脑\  (肾上腺)  (心)       │        █ ✦ ← lit  │
│ / 颈项 /   (肾)   (脾)        │       ▐ ▌         │
│        (   结肠   )           │  ·•·  ▐ ▌ pulse   │
│  胃 胰   ( 小肠 )  │          │       ▐ ▌         │
│        (  膀胱  )             │       ▀ ▀         │
│ ● 头脑 ● 五官 ● 呼吸 ● 消化 …  │                   │
│  chart ≈ 60% · pinch to zoom │  3D body ≈ 40%    │
├──────────────────────────────┴───────────────────┤
│ Kidneys · 肾                          ↻ Replay   │
│ Middle of metacarpal 3, centre of the palm. …    │ ← fixed height: no jump on tap
│ 第3掌骨中点，掌心。…                             │
│ Traditional claim — not medical advice.          │
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
