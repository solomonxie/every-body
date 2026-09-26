# Body Atlas

> 🚧 Work in progress — first demo: Reflex Map and blood flow on a placeholder figure.

A free way to explore the human body in 3D, layer by layer and system by system — skeletal, muscular, circulatory, nervous, organs, digestive, and more. Spin the model, peel back a layer, and see what's underneath, all from your phone, with no purchase required.

Real, licensed anatomy models are a future addition. This build uses a placeholder figure (primitive shapes with the main organs inside, `src/data/anatomy.ts`) to prove out the 3D viewer pipeline — React Native + Expo, rendering through `@react-three/fiber` and `three` via `expo-gl`/`expo-three` — before real assets are sourced.

## Try it

- **Reflex Map (穴位反射图)** — press a foot / hand / ear / body point (dot or name) → a
  pulse travels to the organ it's said to act on, the organ lights up, the effect card shows.
  Filter by region to zoom there.
- **Circulatory** — red/blue blood cells loop heart → arteries → capillaries → veins → lungs;
  drag the heart rate and the flow and heartbeat follow.
- Drag to spin, pinch to zoom, double-tap to reset; ⌂ reset, ◐ gray/white background.

Points: `src/data/system-points.ts` (positions on the figure, target organs).

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

Install on a connected iPhone (Release build, no Metro needed) — put `DEVELOPMENT_TEAM`
and `IOS_BUNDLE_ID` in the gitignored `.env.local` first:

```bash
scripts/install-ios-device.sh
```

App icon: `venv/bin/python scripts/make_icons.py` (needs Pillow in `venv/`).
