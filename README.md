# Body Atlas

> 🚧 Work in progress — skeleton only, not yet functional.

A free way to explore the human body in 3D, layer by layer and system by system — skeletal, muscular, circulatory, nervous, organs, digestive, and more. Spin the model, peel back a layer, and see what's underneath, all from your phone, with no purchase required.

Real, licensed anatomy models are a future addition. This build uses placeholder geometry (simple rotating primitives standing in for each body system) to prove out the 3D viewer pipeline — React Native + Expo, rendering through `@react-three/fiber` and `three` via `expo-gl`/`expo-three` — before real assets are sourced.

## Points, reflex targets & flow animation

`src/types/BodyPoint.ts` + `src/data/system-points.ts` define **points** that can attach to
any system/layer, shown in the Viewer as a tappable chip list (name + description):

- **Acupoint Reflex Map (穴位反射图)** — whole-body acupoints/reflex zones (foot, hand, ear,
  body), each with a `target`: the related body part it affects plus the pressure effect.
  Pressing a point animates a pulse on the model traveling from the point to its target,
  then flashes the target to show the effect landing — implemented in
  `src/components/canvas/reflex-pulse.tsx`, positioned symbolically on the placeholder sphere.
- **Circulatory** — `flow.kind: 'blood'`, a looping flow through
  heart → arteries → capillaries → veins → lungs (stub — not yet animated on the model).

Future work: swap the symbolic placeholder-sphere placement for real positions once licensed
anatomy geometry is sourced (matching how `RotatingMesh` will be swapped out).

## Screen design

- **Viewer** — model centered and rotatable; left edge rail of icon
  buttons (search, layers, settings, info, quiz mode); right edge rail
  (undo, background shade toggle — gray/white). Layers button opens the
  system picker instead of a persistent sidebar.
- **Browse** — 3-column grid of category tiles (thumbnail + label):
  Skeleton, Muscles, Brain, Heart, Organs, Male, Female, Hand, Ear, Foot.
  Tapping a tile jumps the Viewer straight to that system.

## Design docs

[`docs/design/mvp/`](docs/design/mvp/DESIGN.md) — design, UI/UX mockups, implementation plan.

## Setup

```bash
npm install && npx expo start
```
