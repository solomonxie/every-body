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

## Hand & ear charts

Stack page `reflex/[chart]` — from Explore tiles, or Reflex Map › Hand/Ear filter › "Open … chart".

```
 ‹ Back        手部反射区 Hand reflex zones
 (( Left 左 )) ( Right 右 ) (( Palm 掌 )) ( Back 背 ) (( Labels 标注 ))
┌──────────────────────────────────────────────────────┐
│┌──────┐        ___  ___                              │
││ 3D   │  ___  |鼻窦||鼻窦| ___                        │ ← inset: figure, pulse
││ fig  │ |鼻窦|  |  ||  | |鼻窦|                       │   hand/ear → organ
│└──────┘ | 眼 || 眼 || 耳 || 耳 |                       │
│  /大脑\  (      肺·胸       )  肩                     │
│ / 垂体 /  ( 胃 )   (肾)  ( 心 ) ← left palm: 心        │
│/ 颈项 /     (胰)             right palm: 肝          │
│      脊柱  ( 大肠 (小肠) 大肠 )                        │
│       膀胱  (      大肠      )                         │
│             (  生殖腺  )                               │
└──────────────────────────────────────────────────────┘
 ● 头脑 ● 五官 ● 呼吸 ● 心 ● 消化 ● 泌尿 ● 生殖 ● 骨骼关节
│▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁│
│ Kidneys & adrenals · 肾·肾上腺                        │
│ Center of the palm. For fatigue and lower-back ache. │
│ 掌心正中。用于疲劳、腰酸。                              │
│ Traditional claim — not medical advice.  ↻ Replay    │
└──────────────────────────────────────────────────────┘
```
- One drawing per face (right palm, back of left hand, right ear); the other side is mirrored.
  Side-only zones (心 left / 肝 right) filter by side.
- Back of hand + ear: acupoints as dots, label under the dot.
- Tap zone → others dim, pulse leaves the inset figure's hand/ear → organs light → card.
- Ear: one face (耳廓), ~23 points: 耳尖, 神门, 心, 肺, 胃, 肾, 肝, 眼 (lobe), 外鼻/咽喉 (tragus), spine (antihelix)…

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
