# Body Atlas v1 — Design

UI: [UIUX_DESIGN.md](UIUX_DESIGN.md) · Build: [IMPLEMENT_PLAN.md](IMPLEMENT_PLAN.md)

## Problem

Good 3D anatomy apps are paywalled or subscription-gated after a few free parts.
Students, curious people, and reflexology/acupressure learners want to spin a body,
peel layers, and see what a point connects to — on a phone, free, offline.

## Goals

- **Watch, then try** — every feature shows how it works (animation) *and* lets the
  user poke it to see cause → effect (interactive). Passive-only content is out.
- Free, no account, fully offline after install.
- Real 3D body: rotate / zoom / pan, per-system layers, tap a part → name + info.
- Systems: skeletal, muscular, circulatory, nervous, organs, digestive.
- Acupoint Reflex Map (穴位反射图): press a point → pulse travels to the target → effect shown.
- Circulation: animated blood-flow loop.
- Bilingual names: English / 中文 / both.
- Browse by category tile (system or region) → Viewer focused there.
- **Illustrations (图解)** — step-by-step animated scenarios on the model, v1.1+:
  - Bones: dislocation & fracture, reduction / setting (骨头错位、接骨).
  - First aid: CPR, choking, bleeding, burns, sprain, splinting a fracture, recovery position.
  - Blood metrics: blood sugar (glucose ↔ insulin), blood pressure, blood fats (plaque build-up).
  - Common illnesses: cold/flu, gastritis, hypertension, diabetes, stroke, heart attack,
    appendicitis, kidney stones.
  - Pregnancy & labor: fetal growth by week, stages of labor.

## Non-goals (v1)

- Medical advice, diagnosis, treatment plans.
- Accounts, sync, social, ads, IAP.
- AR, VR, dissection-grade detail (individual vessels/nerves beyond what the source model has).
- Full female model — until a licensed asset exists (see Risks). Pregnancy uses a
  dedicated pelvis/uterus sub-model instead.
- Self-treatment instructions: bone-setting illustrations show what a clinician does,
  never "do this at home". First aid is the one exception, and only per current guidelines.
- Quiz mode — post-v1; the Viewer reserves its rail slot.
- Web as a target — Expo web may run, not supported.

## Options considered

**3D stack**

| Option | Deciding factor |
|---|---|
| R3F + `expo-gl`/`expo-three` ✓ | Already working; one codebase; three.js ecosystem (GLTFLoader, raycast) |
| Native SceneKit / Filament | Best perf, but two renderers to maintain |
| WebView + three.js | Easy, but gesture/bridge lag, poor GL on older Android |
| Unity as a library | Heavy binary, second toolchain |

**Anatomy asset**

| Option | Deciding factor |
|---|---|
| Z-Anatomy (CC BY-SA 4.0, from BodyParts3D) ✓ | Free, full body, named parts, Blender source → glTF |
| BodyParts3D raw (CC BY-SA 2.1 JP) | Same data, less cleanup, no organized collections |
| Commercial (Zygote etc.) | Best quality, licence cost + no-redistribution terms conflict with free |
| Build our own | Not feasible |

**Asset delivery**

| Option | Deciding factor |
|---|---|
| Bundle per-system GLB (Draco/meshopt) ✓ | Offline from first launch; lazy-load per system keeps memory low |
| Download on demand | Smaller install, but breaks "offline" and needs hosting |

**Illustrations**

| Option | Deciding factor |
|---|---|
| Scenario = data-driven steps over the live model ✓ | Reuses camera, layers, pulse/flow engines; one player for all topics; bilingual captions free |
| Pre-rendered videos | Easy to author, but big, not rotatable, per-language renders |
| 2D illustrated cards | Cheap, but loses the 3D value of the app |

**Interactivity**

| Option | Deciding factor |
|---|---|
| Small shared set of interaction primitives, bound to scene params ✓ | Every topic gets a "Try" with no bespoke code; consistent to learn |
| Bespoke mini-game per topic | Richest, but per-topic engineering; doesn't scale to 25+ topics |
| Quiz questions only | Tests recall, doesn't show mechanism |

## Decision

- R3F + expo-gl — keeps the working pipeline; swap only the geometry.
- Z-Anatomy → one compressed GLB per system, bundled, loaded lazily. Stable part ids
  from node names so data (info, points, search) keys on them.
- Points anchored to mesh-surface coordinates, replacing placeholder-sphere lat/lon.
- Reflex effects framed as traditional claims, with a disclaimer — not as medical fact.
- Illustrations = `Scenario` data (ordered steps: camera, layers, part transforms/tints,
  overlays like particles/arrows/gauges, caption EN/中). One player; new topics = new data,
  plus a few overlay primitives (particles, arrows, gauge, displaced-part transform).
- Ship after core v1: they depend on real parts, picking and the pulse/flow engines.
- Interactivity = 6 primitives, each drives scene params declared by the data:
  **scrub** (slider → value, e.g. glucose, gestation week), **drag-to-target** (move a
  part, snaps + feedback, e.g. reduce a shoulder), **rhythm tap** (timing + rate feedback,
  e.g. CPR 100–120/min), **press & hold** (duration, e.g. pressure on bleeding),
  **toggle/compare** (healthy ⇄ affected, split view), **follow** (camera rides a particle).
  A scenario step is `watch` (animated) or `try` (primitive + success condition).

## Data & integrations

- Static, bundled: models (GLB), part metadata (`id`, names EN/中, system, region,
  description), points (`BodyPoint` + target), flows, scenarios (steps + sources).
- Local only: settings (name language, theme, background, quality, auto-rotate).
- No backend, no network, no analytics. Running cost: $0 + store fees.
- Credits: Z-Anatomy / BodyParts3D attribution in-app (About → Licenses).

## Risks / open questions

- **Share-alike**: CC BY-SA applies to the converted models — publish them (or the
  conversion script + source link). App code licence unaffected; confirm before release.
- **Install size**: full body can exceed 100 MB raw; target ≤ 60 MB total after
  compression + decimation. May force download-on-demand for detailed systems.
- **Low-end Android GL**: expo-gl perf on 3 GB devices; needs a Low quality tier.
- **Health claims / store review**: reflex effects must read as tradition, not efficacy
  (Apple 1.4.1). Sources: WHO Standard Acupuncture Point Locations (2008) for placement.
- **Female model**: no free, licensed equivalent known — Male/Female tiles stay hidden.
  Pregnancy/labor needs a pelvis + uterus + fetus-by-stage sub-model: source (CC model)
  or commission — the single biggest unknown for that topic.
- **Medical accuracy of Illustrations**: first aid must track current ILCOR / Red Cross
  guidance (updated every ~5 y); illness and metric content needs a clinician review and
  cited sources per scenario. Store review scrutiny higher (Apple 1.4.1).
- **Graphic content**: fractures, labor — keep stylized (no gore), age rating 12+.
- Reflex zones on feet/hands/ears need detailed local geometry; body-scale model may be
  too coarse → possible dedicated foot/hand/ear sub-models.
