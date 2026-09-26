# Points sheet — Reflex Map & Blood flow

Persistent bottom sheet on the Viewer when the system has points
(`POINTS_BY_SYSTEM`). Code: `src/components/canvas/reflex-pulse.tsx`, `src/data/system-points.ts`.

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
