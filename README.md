# Body Atlas

> 🚧 Work in progress — skeleton only, not yet functional.

A free way to explore the human body in 3D, layer by layer and system by system — skeletal, muscular, circulatory, nervous, organs, digestive, and more. Spin the model, peel back a layer, and see what's underneath, all from your phone, with no purchase required.

Real, licensed anatomy models are a future addition. This build uses placeholder geometry (simple rotating primitives standing in for each body system) to prove out the 3D viewer pipeline — React Native + Expo, rendering through `@react-three/fiber` and `three` via `expo-gl`/`expo-three` — before real assets are sourced.

## Screen design

- **Viewer** — model centered and rotatable; left edge rail of icon
  buttons (search, layers, settings, info, quiz mode); right edge rail
  (undo, background shade toggle — gray/white). Layers button opens the
  system picker instead of a persistent sidebar.
- **Browse** — 3-column grid of category tiles (thumbnail + label):
  Skeleton, Muscles, Brain, Heart, Organs, Male, Female, Hand, Ear, Foot.
  Tapping a tile jumps the Viewer straight to that system.

## Setup

```bash
npm install && npx expo start
```
