# Body Atlas — Implementation plan

Why: [DESIGN.md](DESIGN.md) · What it looks like: [UIUX_DESIGN.md](UIUX_DESIGN.md).
`depends: none` tasks within a phase are the parallel batch.

## Phase 1: Foundations
Data types, settings, and name display every later screen reads. No 3D dependency, so
it unblocks both the UI and asset tracks.

- [x] T1.1 Expo Router + TS scaffold, tabs, Viewer/Info stubs — see `src/app` — depends: none
- [x] T1.2 `BodyPoint` / `FlowPath` types + reflex & circulation point data — see `src/types`, `src/data` — depends: none
- [x] T1.3 Placeholder reflex pulse on sphere — see `src/components/canvas/reflex-pulse.tsx` — depends: T1.2
- [x] T1.4 `Category` model + Explore tile presets (systems, focus) — see `uiux/explore.md` → Tile table, `src/data/categories.ts` — depends: none
- [x] T1.5 Settings store (names, theme, background, quality, auto-rotate), persisted via AsyncStorage — see `src/state/settings.ts` — depends: none
- [ ] T1.6 `BilingualName` + string table (in-progress: `useName`/`useBilingual` wired to cards and captions; no string table) (copy keys from `uiux/*.md`) — see `uiux/components.md` → BilingualName, `src/i18n/` — depends: T1.5
- [ ] T1.7 CI: `tsc --noEmit` + `expo lint` on push — see `.github/workflows/` — depends: none

## Phase 2: App shell on placeholder geometry
Build every v1 screen against the existing sphere so UI work doesn't wait on assets.

- [x] T2.1 Explore: search field, 3-col `CategoryTile` grid — see `uiux/explore.md` — depends: T1.4, T1.6
- [x] T2.2 Viewer frame: full-bleed canvas, `RailButton` rails, ◐ background, ⌂ reset — see `uiux/viewer.md` — depends: T1.5
- [x] T2.3 Camera controls: orbit / pinch / pan / double-tap, auto-rotate until first touch — see `src/components/canvas/` — depends: T2.2
- [ ] T2.4 `Sheet` component (peek/half/full, one-at-a-time) + Toast — see `uiux/components.md` — depends: none
- [x] T2.5 Settings screen + disclaimer + sources (one page) — see `uiux/settings.md` — depends: T1.5, T1.6
- [ ] T2.6 Viewer states: loading, error, no-GL, first-run hint — see `uiux/viewer.md` → States — depends: T2.2
- [x] T2.7 Review build: primitive mannequin with organs, Reflex Map press → pulse → organ, blood flow + heart-rate try, app icon, device install script — see `src/components/canvas`, `scripts/` — depends: none

## Phase 3: Schematic body
Parts, points and scenarios anchor to the body's part ids, so the procedural body must
cover every system before later phases. Schematic geometry only (DESIGN → Decision).

- [x] T3.0 Primitive mannequin with main organs + regions — see `src/data/anatomy.ts` — depends: none
- [x] T3.1 Part schema: id, EN/中 names, system, region, parent, primitive params — see `src/data/anatomy.ts` — depends: T3.0
- [x] T3.2 Skeletal system as primitives (skull, spine segments, ribs, pelvis, limb bones, joints) — see `src/data/anatomy.ts` — depends: T3.1
- [x] T3.3 Muscular, nervous, digestive, circulatory as primitives/curves (tubes along splines) — see `src/data/anatomy.ts` — depends: T3.1
- [x] T3.4 `SchematicBody`: layers by system, per-part visibility — see `src/components/canvas/schematic-body.tsx` — depends: T3.2, T3.3
- [ ] T3.5 Tile thumbnails rendered from the schematic body — see `scripts/` — depends: T3.4
- Deferred: Z-Anatomy GLB pipeline (`asset-pipeline.md`) — only if schematic proves insufficient

## Phase 4: Part interaction
Picking and per-part state; Search and Part info key on the same part ids.

- [x] T4.1 Raycast picking + highlight + Part card — see `uiux/viewer.md` → Part card — depends: T3.4, T2.4
- [x] T4.2 Viewer part state (hide / isolate / fade) + undo stack — see `src/state/viewer.ts` — depends: T3.4
- [ ] T4.3 Layers sheet + Display sheet (in-progress: layer pill bar done) — see `uiux/viewer.md` → Layers / Display — depends: T4.2, T2.4
- [ ] T4.4 Part info page (part / point / system variants), Show on model (in-progress: system pages with facts, links, tappable parts) — see `uiux/part-info.md` — depends: T3.1
- [x] T4.5 Search index (EN, 中文) over systems, illustrations, zones, points, parts — pinyin and recents not yet — see `uiux/search.md` — depends: T3.1, T2.4

## Phase 5: Points & flow on the real model
Move the existing sphere-based points onto mesh surfaces; the pulse/flow engines here are
reused by Phase 7 overlays.

- [ ] T5.1 Point anchors: replace lat/lon with part id + surface position; re-place all points — see `src/types/BodyPoint.ts`, `src/data/system-points.ts` — depends: T3.1
- [ ] T5.2 Surface-path reflex pulse + target flash + camera framing — see `uiux/points.md` → Press sequence — depends: T5.1
- [ ] T5.3 Points sheet: filter, chips, effect card, claim ⓘ — see `uiux/points.md` — depends: T5.1, T2.4
- [ ] T5.4 Blood-flow particle engine along vessel path, pause/speed, stops — see `uiux/points.md` → Blood flow — depends: T5.1
- [x] T5.5 Hand, foot + ear reflex charts (pinch-zoom; organ → zones reverse lookup) (geometric SVG, zones per standard maps, L/R mirror, palm/back, 3D inset pulse) — see `uiux/points.md` → Hand & ear charts, `src/data/reflex-charts.ts` — depends: T5.1

## Phase 6: v1 release
Ship core atlas before Illustrations; store review, size, and perf gate everything after.

- [ ] T6.1 Reduce-motion variants (pulse, flow, camera) (in-progress: auto-rotate off, illustration steps jump) — see `uiux/points.md` → States — depends: T5.2, T5.4
- [ ] T6.2 Perf pass on a low-end Android + Low quality auto-detect — see `src/components/canvas/` — depends: T3.4, T5.4
- [ ] T6.3 Install-size budget check (≤ 30 MB) — see `app.json` — depends: T3.4
- [ ] T6.4 Store listing, age rating 12+, health-claim wording review — see `DESIGN.md` → Risks — depends: T5.3, T2.5

## Phase 7: Scenario engine — Watch
One data-driven player for every Illustration; must exist before any topic is authored.

- [x] T7.1 `Scenario` / `Step` schema (2D SVG scene per topic, params eased per step) — see `scenario-format.md` — depends: T3.1
- [x] T7.2 Step runner (cumulative step targets, per-frame easing, `pulse`/instant params) — was: camera, layers, part transform/tint tweens, captions — see `scenario-format.md` → Runner — depends: T7.1, T4.2
- [ ] T7.3 Overlay primitives: arrow, particles (reuse T5.4), gauge, plaque/narrowing, counter — see `uiux/illustrations.md` → Overlay primitives — depends: T7.1, T5.4
- [x] T7.4 Player UI: step dots, Prev/Next, auto-advance, end state, clinician-only hint — see `uiux/illustrations.md` → Player — depends: T7.2
- [ ] T7.5 Explore ILLUSTRATIONS section + Topic list (in-progress: section done, topic list page when >1 screen of topics) — see `uiux/illustrations.md` → Explore section / Topic list — depends: T7.1, T2.1

## Phase 8: Interactivity — Try
The six primitives, shared by Illustrations and by parts/points/flow in the Viewer.

- [x] T8.1 `TryControl` modes: scrub, rhythm, hold, compare (+ feedback line) — see `uiux/components.md` → TryControl — depends: T7.2
- [x] T8.2 In-scene drag-to-target (handle, ghost, snap, arc guide) — see `uiux/illustrations.md` → Watch ⇄ Try — depends: T7.2
- [ ] T8.3 Compare split view (two model states side by side / drag split) — see `scenario-format.md` → Compare — depends: T7.2
- [ ] T8.4 Follow camera (ride a particle) — see `src/components/canvas/` — depends: T5.4
- [ ] T8.5 Viewer Try on parts: joint pivots/ROM, muscle contract, organ rate — see `uiux/viewer.md` → Try on a part — depends: T8.1, T8.2, T4.1
- [ ] T8.6 Circulation try: heart-rate scrub + follow a cell — see `uiux/points.md` → Blood flow — depends: T8.1, T8.4

## Phase 9: Illustration content
Pure data + review per group; groups are independent — one agent each. Every topic ships
watch + try steps, EN/中 captions, cited sources, clinician sign-off.

- [x] T9.0 First topics: shoulder dislocation (drag), CPR (rhythm), blood sugar / pressure / fats (scrub, math models) — see `src/illustrations/scenes/` — depends: T7.4
- [x] T9.0b More topics: fracture setting & healing, choking, severe bleeding, burns, stroke, heart attack, cold vs flu, fetal growth, labour — see `src/illustrations/scenes/` — depends: T8.1
- [ ] T9.1 Bones & setting: dislocations, fracture + casting, healing — see `uiux/illustrations.md` → Per-topic try — depends: T7.3, T8.2
- [ ] T9.2 First aid ×7 (ILCOR-based) + emergency-number reminder — see `uiux/illustrations.md` — depends: T7.3, T8.1, T8.2
- [ ] T9.3 Blood sugar / pressure / fats — see `uiux/illustrations.md` → Metric topic — depends: T7.3, T8.1
- [ ] T9.4 Common illnesses ×8 — see `uiux/illustrations.md` — depends: T7.3, T8.3
- [ ] T9.5 Schematic pregnancy sub-model (pelvis, uterus, fetus by week as parametric shapes) — see `DESIGN.md` → Risks — depends: T3.1
- [ ] T9.6 Pregnancy & labor topics — see `uiux/illustrations.md` — depends: T9.5, T7.3, T8.1
- [ ] T9.7 Medical review pass + sources page per topic — see `DESIGN.md` → Risks — depends: T9.1, T9.2, T9.3, T9.4

## Phase 10: Later
- [x] T10.1 Quiz mode: name the glowing part, 10 rounds, per system — see `src/app/quiz/[id].tsx` — depends: T4.4
- [x] T10.2 Schematic female variant (pelvis, reproductive organs) — see `src/data/anatomy.ts` — depends: T3.2
