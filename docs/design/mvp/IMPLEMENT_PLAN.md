# Body Atlas — Implementation plan

Why: [DESIGN.md](DESIGN.md) · What it looks like: [UIUX_DESIGN.md](UIUX_DESIGN.md).
`depends: none` tasks within a phase are the parallel batch.

## Phase 1: Foundations
Data types, settings, and name display every later screen reads. No 3D dependency, so
it unblocks both the UI and asset tracks.

- [x] T1.1 Expo Router + TS scaffold, tabs, Viewer/Info stubs — see `src/app` — depends: none
- [x] T1.2 `BodyPoint` / `FlowPath` types + reflex & circulation point data — see `src/types`, `src/data` — depends: none
- [x] T1.3 Placeholder reflex pulse on sphere — see `src/components/canvas/reflex-pulse.tsx` — depends: T1.2
- [ ] T1.4 `Category` model + Explore tile presets (systems, focus) — see `uiux/explore.md` → Tile table, `src/data/categories.ts` — depends: none
- [ ] T1.5 Settings store (names, theme, background, quality, auto-rotate), persisted via AsyncStorage — see `src/state/settings.ts` — depends: none
- [ ] T1.6 `BilingualName` + string table (copy keys from `uiux/*.md`) — see `uiux/components.md` → BilingualName, `src/i18n/` — depends: T1.5
- [ ] T1.7 CI: `tsc --noEmit` + `expo lint` on push — see `.github/workflows/` — depends: none

## Phase 2: App shell on placeholder geometry
Build every v1 screen against the existing sphere so UI work doesn't wait on assets.

- [ ] T2.1 Explore: search field, 3-col `CategoryTile` grid — see `uiux/explore.md` — depends: T1.4, T1.6
- [ ] T2.2 Viewer frame: full-bleed canvas, `RailButton` rails, ◐ background, ⌂ reset — see `uiux/viewer.md` — depends: T1.5
- [ ] T2.3 Camera controls: orbit / pinch / pan / double-tap, auto-rotate until first touch — see `src/components/canvas/` — depends: T2.2
- [ ] T2.4 `Sheet` component (peek/half/full, one-at-a-time) + Toast — see `uiux/components.md` — depends: none
- [ ] T2.5 Settings screen + Licenses + Disclaimer pages — see `uiux/settings.md` — depends: T1.5, T1.6
- [ ] T2.6 Viewer states: loading, error, no-GL, first-run hint — see `uiux/viewer.md` → States — depends: T2.2

## Phase 3: Anatomy asset pipeline
Real geometry is what parts, points and scenarios all anchor to; nothing past Phase 3
is meaningful on a sphere.

- [ ] T3.1 Confirm licence terms + publish plan for converted models — see `DESIGN.md` → Risks — depends: none
- [ ] T3.2 Blender → per-system GLB conversion script (ids, decimate, Draco/meshopt, Low tier) — see `asset-pipeline.md` — depends: T3.1
- [ ] T3.3 Part metadata extract: id, EN/中 names, system, region, parent — see `asset-pipeline.md` → Metadata — depends: T3.2
- [ ] T3.4 Tile thumbnails rendered from GLBs — see `asset-pipeline.md` → Thumbnails — depends: T3.2
- [ ] T3.5 Runtime loader: lazy per-system GLB via expo-asset + GLTFLoader, progress events — see `src/components/canvas/` — depends: T3.2, T2.6
- [ ] T3.6 Replace `RotatingMesh` with `BodyModel` (layers by system, quality tier) — see `src/components/canvas/` — depends: T3.5

## Phase 4: Part interaction
Picking and per-part state; Search and Part info key on the same part ids.

- [ ] T4.1 Raycast picking + highlight + Part card — see `uiux/viewer.md` → Part card — depends: T3.6, T2.4
- [ ] T4.2 Viewer part state (hide / isolate / fade / layer opacity) + undo stack — see `src/state/viewer.ts` — depends: T3.6
- [ ] T4.3 Layers sheet + Display sheet — see `uiux/viewer.md` → Layers / Display — depends: T4.2, T2.4
- [ ] T4.4 Part info page (part / point / system variants), Show on model — see `uiux/part-info.md` — depends: T3.3
- [ ] T4.5 Search index (EN, 中文, pinyin) + Search sheet + recents — see `uiux/search.md` — depends: T3.3, T2.4

## Phase 5: Points & flow on the real model
Move the existing sphere-based points onto mesh surfaces; the pulse/flow engines here are
reused by Phase 7 overlays.

- [ ] T5.1 Point anchors: replace lat/lon with part id + surface position; re-place all points — see `src/types/BodyPoint.ts`, `src/data/system-points.ts` — depends: T3.3
- [ ] T5.2 Surface-path reflex pulse + target flash + camera framing — see `uiux/points.md` → Press sequence — depends: T5.1
- [ ] T5.3 Points sheet: filter, chips, effect card, claim ⓘ — see `uiux/points.md` — depends: T5.1, T2.4
- [ ] T5.4 Blood-flow particle engine along vessel path, pause/speed, stops — see `uiux/points.md` → Blood flow — depends: T5.1

## Phase 6: v1 release
Ship core atlas before Illustrations; store review, size, and perf gate everything after.

- [ ] T6.1 Reduce-motion variants (pulse, flow, camera) — see `uiux/points.md` → States — depends: T5.2, T5.4
- [ ] T6.2 Perf pass on a low-end Android + Low quality auto-detect — see `src/components/canvas/` — depends: T3.6, T5.4
- [ ] T6.3 Install-size budget check (≤ 60 MB) — see `asset-pipeline.md` → Budget — depends: T3.2
- [ ] T6.4 Store listing, age rating 12+, health-claim wording review — see `DESIGN.md` → Risks — depends: T5.3, T2.5

## Phase 7: Scenario engine — Watch
One data-driven player for every Illustration; must exist before any topic is authored.

- [ ] T7.1 `Scenario` / `Step` schema + validator — see `scenario-format.md` — depends: T3.3
- [ ] T7.2 Step runner: camera, layers, part transform/tint tweens, captions — see `scenario-format.md` → Runner — depends: T7.1, T4.2
- [ ] T7.3 Overlay primitives: arrow, particles (reuse T5.4), gauge, plaque/narrowing, counter — see `uiux/illustrations.md` → Overlay primitives — depends: T7.1, T5.4
- [ ] T7.4 Player UI: step dots, Prev/Next, auto-advance, end state, clinician-only hint — see `uiux/illustrations.md` → Player — depends: T7.2
- [ ] T7.5 Explore ILLUSTRATIONS section + Topic list — see `uiux/illustrations.md` → Explore section / Topic list — depends: T7.1, T2.1

## Phase 8: Interactivity — Try
The six primitives, shared by Illustrations and by parts/points/flow in the Viewer.

- [ ] T8.1 `TryControl` sheet modes: scrub, rhythm, hold, compare (+ feedback line) — see `uiux/components.md` → TryControl — depends: T7.2
- [ ] T8.2 In-scene drag-to-target (handle, ghost, snap, arc guide) — see `uiux/illustrations.md` → Watch ⇄ Try — depends: T7.2
- [ ] T8.3 Compare split view (two model states side by side / drag split) — see `scenario-format.md` → Compare — depends: T7.2
- [ ] T8.4 Follow camera (ride a particle) — see `src/components/canvas/` — depends: T5.4
- [ ] T8.5 Viewer Try on parts: joint pivots/ROM, muscle contract, organ rate — see `uiux/viewer.md` → Try on a part — depends: T8.1, T8.2, T4.1
- [ ] T8.6 Circulation try: heart-rate scrub + follow a cell — see `uiux/points.md` → Blood flow — depends: T8.1, T8.4

## Phase 9: Illustration content
Pure data + review per group; groups are independent — one agent each. Every topic ships
watch + try steps, EN/中 captions, cited sources, clinician sign-off.

- [ ] T9.1 Bones & setting: dislocations, fracture + casting, healing — see `uiux/illustrations.md` → Per-topic try — depends: T7.3, T8.2
- [ ] T9.2 First aid ×7 (ILCOR-based) + emergency-number reminder — see `uiux/illustrations.md` — depends: T7.3, T8.1, T8.2
- [ ] T9.3 Blood sugar / pressure / fats — see `uiux/illustrations.md` → Metric topic — depends: T7.3, T8.1
- [ ] T9.4 Common illnesses ×8 — see `uiux/illustrations.md` — depends: T7.3, T8.3
- [ ] T9.5 Pregnancy sub-model sourcing (pelvis, uterus, fetus by stage) — see `DESIGN.md` → Risks — depends: T3.2
- [ ] T9.6 Pregnancy & labor topics — see `uiux/illustrations.md` — depends: T9.5, T7.3, T8.1
- [ ] T9.7 Medical review pass + sources page per topic — see `DESIGN.md` → Risks — depends: T9.1, T9.2, T9.3, T9.4

## Phase 10: Later
- [ ] T10.1 Quiz mode (rail slot reserved) — needs its own design pass — depends: T4.4
- [ ] T10.2 Female model — depends: a licensed asset (DESIGN Risks)
