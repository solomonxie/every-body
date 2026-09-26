# Scenario format (T7.1–T7.2, T8.3)

Built: `src/illustrations/` — each topic is a `Scenario` with a 2D SVG `Scene({ params, t })`
drawn from math (per DESIGN → schematic, not lifelike); steps set param targets, the player
eases toward them each frame. Try modes: `scrub`, `rhythm`, `drag` (scene `onDrag` maps the
finger to params). The 3D-body fields below remain the target for topics that need the body.


One file per topic: `src/data/scenarios/<group>/<topic>.ts`.

```ts
Scenario {
  id, group, title: { en, zh }, model?: 'body' | 'pregnancy'
  sources: string[]            // cited, shown on the sources page
  clinicianOnly?: boolean      // shows the "don't try it yourself" hint
  params: { [name]: { min, max, unit, initial } }   // e.g. glucose, week, flexion
  steps: Step[]
}

Step {
  kind: 'watch' | 'try'
  caption: { en, zh }
  camera?: { focus: partId | region, distance?, yaw?, pitch? }
  layers?: { [system]: opacity }
  parts?: { [partId]: { visible?, tint?, offset?, rotate?: { pivot, deg } } }
  overlays?: Overlay[]         // arrow | particles | gauge | plaque | counter
  bind?: { [param]: Binding }  // param → part transform / overlay prop / particle rate
  duration?: ms                // watch only
  try?: { mode, param?, target?, rate?, holdMs?, successWhen, feedback: { ok, hints[] } }
}
```

## Runner

- Entering a step tweens from the previous step's resolved state (≤ 800 ms, ease-in-out).
- `bind` maps are pure functions of params → scene props; scrub/drag just set params.
- Try success → feedback `ok`, enables Next; hints fire on rule matches (too fast, wrong way).
- Parts not mentioned keep their state; `‹` discards all scenario state.

## Pivots

Models aren't rigged. Joint rotation uses pivot points in `src/data/pivots.ts`
(`{ jointId, pivot: [x,y,z], axis, rangeDeg, childParts[] }`), shared with Viewer "Try on a part".

## Compare

`try.mode = 'compare'` declares two part/overlay states `a` and `b`; the view renders
both — segmented switch (default) or drag split (two scissor-rect viewports, one camera).
