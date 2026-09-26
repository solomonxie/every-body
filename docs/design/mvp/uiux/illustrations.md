# Illustrations (图解)

Step-by-step animated scenarios played on the live model. Entry: Explore → ILLUSTRATIONS
section → Topic list → Player. Why/scope: `DESIGN.md` → Illustrations.

## Explore section

Below the system grid on Explore; one row per topic group.

```
 ILLUSTRATIONS · 图解
 ╭──────────────────────────────────────────────────╮
 │ 🦴 Bones & setting · 骨折与接骨               (4) ›│
 ├──────────────────────────────────────────────────┤
 │ ✚ First aid · 急救                           (7) ›│
 ├──────────────────────────────────────────────────┤
 │ 🩸 Blood sugar, pressure & fats · 三高        (3) ›│
 ├──────────────────────────────────────────────────┤
 │ Common illnesses · 常见病                    (8) ›│
 ├──────────────────────────────────────────────────┤
 │ Pregnancy & labor · 孕产                     (2) ›│
 ╰──────────────────────────────────────────────────╯
```

## Topic list

```
 ‹ Explore        First aid · 急救
 ──────────────────────────────────────────────────────
 ╭──────────────────────────────────────────────────╮
 │ (thumb) CPR · 心肺复苏             6 steps · 1 min ›│
 ├──────────────────────────────────────────────────┤
 │ (thumb) Choking · 气道异物梗阻     5 steps       ›│
 ├──────────────────────────────────────────────────┤
 │ (thumb) Severe bleeding · 大出血   4 steps       ›│
 ├──────────────────────────────────────────────────┤
 │ (thumb) Burns · 烧烫伤             4 steps       ›│
 ├──────────────────────────────────────────────────┤
 │ (thumb) Sprain · 扭伤              4 steps       ›│
 ├──────────────────────────────────────────────────┤
 │ (thumb) Splinting a fracture · 骨折固定 5 st…    ›│
 ├──────────────────────────────────────────────────┤
 │ (thumb) Recovery position · 复原卧位 4 steps     ›│
 ╰──────────────────────────────────────────────────╯
 Based on ILCOR 2025 guidance. ⓘ
```

Topic catalogue (v1.1 target):

| Group | Topics |
|---|---|
| Bones & setting | Shoulder dislocation + reduction · Finger dislocation · Forearm fracture + casting · How a fracture heals |
| First aid | CPR · Choking · Severe bleeding · Burns · Sprain · Splinting a fracture · Recovery position |
| Blood metrics | Blood sugar · Blood pressure · Blood fats |
| Common illnesses | Cold & flu · Gastritis · Hypertension · Diabetes · Stroke · Heart attack · Appendicitis · Kidney stones |
| Pregnancy & labor | Fetal growth by week · Stages of labor |

## Player

Viewer in scenario mode: rails swap to player controls, captions in a bottom sheet.

```
 ‹ Bones        Shoulder dislocation            2 / 5
┌──────────────────────────────────────────────────────┐
│                                                   ↶  │
│               (torso, skin 20%, skeletal)            │
│                   ___                                │
│                  /   \  ← humerus head, tinted,      │
│                 ( ◉ ↘ )    shifted out of socket     │
│                  \___/                               │
│                                                      │
│▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁│
│ ●●○○○                                                │
│ The ball of the upper arm slips forward out of the   │
│ shoulder socket.                                     │
│ 肱骨头向前滑出肩关节盂。                               │
│ ( ‹ Prev )            ( ❚❚ )             ( Next › )  │
└──────────────────────────────────────────────────────┘
```
- Each step animates camera + layers + parts, then holds; model stays rotatable.
- Swipe the caption ◀ ▶ = Prev / Next. Step dots tappable.
- Auto-advance off by default; ❚❚/▶ toggles it.

### Watch ⇄ Try

Every topic mixes `watch` steps (animate, then hold) and `try` steps (user drives it).
Step dots show which: ● watch, ◆ try.

```
 ●●◆○◆                                    ← step 3 = try
 Your turn: drag the arm to guide the head back in.
 ┌──────────────────────────────────────────────┐
 │           ◌ ← ghost: target position         │
 │          ↖                                   │
 │        ( ◉ )  ← drag ▲ along the guide arc   │
 └──────────────────────────────────────────────┘
 ✓ success   ✦ snap + joint flashes green, "Back in place." → Next enabled
 ✗ wrong way ⚠ edge flashes, "Too much force outward — follow the arc."
 ( Show me )  ← plays the watch version, then returns to try
```
Try steps never block: ( Show me ) and ( Skip ) always available.

### Try primitives

```
scrub         Glucose  ├──────●────┤ 11.1 mmol/L    scene follows the value live
drag-to-target  ( ◉ ) ──▶ ◌                         snaps within tolerance
rhythm tap    ◯ tap ↓ ↓ ↓   112/min ✓  depth ▓▓▓░ ✓  CPR: rate + consistency score
press & hold  ◯ hold ▓▓▓▓░░ 7 s                     bleeding slows while held
compare       [ HEALTHY | Hypertension ]  or  ◀ drag split ▶  side-by-side
follow        ⊙ Follow a blood cell                 camera rides one particle
```

Per-topic try (v1.1 target):

| Topic | Try |
|---|---|
| Shoulder / finger dislocation | drag-to-target: reduce the joint |
| Fracture + casting / healing | scrub: weeks 0 → 12, callus forms |
| CPR | rhythm tap: 30 compressions, rate + depth feedback |
| Choking | drag-to-target: hand placement, then 5 thrust taps |
| Severe bleeding | press & hold: direct pressure, flow slows |
| Burns | scrub: cool-water minutes → heat map fades |
| Sprain | compare: normal ⇄ torn ligament, drag ankle to see stretch |
| Splinting / recovery position | drag-to-target: place splint / roll the body |
| Blood sugar | scrub: meal, insulin, exercise sliders → glucose particles |
| Blood pressure | scrub: heart rate, vessel stiffness → gauge + wall stretch |
| Blood fats | scrub: years of high LDL → plaque grows, flow narrows |
| Illnesses | compare: healthy ⇄ affected organ; stroke/heart attack: tap to block a vessel, watch downstream tissue |
| Fetal growth | scrub: week 4 → 40 |
| Labor | scrub: cervix 0 → 10 cm, stage labels follow |

### Overlay primitives (draw per topic)

```
displaced part    ( ◉ ↘ )         part transform + accent tint, ghost at home position
arrow / force     ──▶  ⇒          push, pull, pressure direction (CPR compressions)
particles         · • · • ─▶      glucose, clots, blood cells (reuses flow engine)
gauge             ├────●──┤ 145/95 mmHg   metric value tied to the step
plaque / narrow   ═══▓▓═══        vessel lumen narrowing (blood fats, heart attack)
counter           30 : 2          CPR compressions : breaths, with a 100–120/min beat
```

### Metric topic (blood sugar)

```
 ‹ Blood metrics      Blood sugar                3 / 4
┌──────────────────────────────────────────────────────┐
│     (vessel cross-section, zoomed)                   │
│   ═════════════════════════════════════             │
│     •  •   •    ◇  •   •  → cell                     │ ← • glucose, ◇ insulin
│   ═════════════════════════════════════             │
│  Glucose  ├──────────●────────┤ 11.1 mmol/L          │ ← drag to scrub scenario value
│▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁│
│ ●●●○                                                 │
│ Without enough insulin, glucose stays in the blood.  │
└──────────────────────────────────────────────────────┘
```
Gauge is illustrative — never takes the user's own readings.

## States

```
first open    ⌐ This shows what a clinician does — don't try it yourself. ¬
              ← Bones & setting topics only, once per topic
loading       ⟳ Loading Shoulder…  [█████░░░░░] 50%
missing model ⚠ Needs the pregnancy model — not available yet.   ← hides topic in list instead in release
end           ✓ Done.   ( Replay )   ( Show in Viewer ›)
reduce motion steps cut instead of animate; particles become static arrows
```

## Interactions

| Target | Action | Result |
|---|---|---|
| topic row | tap | Player at step 1 |
| Next / Prev / dot | tap | animate to that step |
| part in scene | tap | Part card (same as Viewer) — scenario pauses |
| gauge | drag | scrub value; scene follows (metric topics) |
| Show in Viewer | tap | Viewer on that region, normal mode |
| ‹ | tap | back to topic list; progress not kept |

## Copy

| Key | String |
|---|---|
| `illus.section` | Illustrations · 图解 |
| `illus.steps` | {n} steps |
| `illus.prev` / `next` | Prev / Next |
| `illus.done` | Done. |
| `illus.replay` | Replay |
| `illus.showInViewer` | Show in Viewer |
| `illus.clinicianOnly` | This shows what a clinician does — don't try it yourself. |
| `illus.firstAid.source` | Based on ILCOR 2025 guidance. |
| `illus.firstAid.source.info` | First aid steps follow the International Liaison Committee on Resuscitation guidance. In an emergency, call your local emergency number first. |
| `illus.metric.note` | Illustrative values, not a reading. |

## Notes

- First aid topics show an emergency-number reminder on step 1: "Call 120 / 911 first."
  — number from device region.
- Graphic level: stylized tint + transform only, no blood/wound textures.
