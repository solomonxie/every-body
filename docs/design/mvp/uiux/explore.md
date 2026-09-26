# Home

The app's only root page (no tab bar). Code: `Sources/Screens/ExploreView.swift`.

```
 Every Body                                 [👤 Adult M ▾]
 ┌────────────────────────────────────────────────────┐
 │ 🔍 Body parts, illnesses, procedures               │  ← typing swaps sections for results
 └────────────────────────────────────────────────────┘
 Human body
 ┌────────────────┬────────────────┬────────────────┐
 │  (skeleton)    │  (muscles)     │  (vessels)     │
 │ Skeletal       │ Muscular       │ Circulatory    │
 ├────────────────┼────────────────┼────────────────┤
 │ Nervous        │ Organs         │ Digestive      │
 └────────────────┴────────────────┴────────────────┘
 Reflex & acupressure
 ┌────────────────┬────────────────┬────────────────┐
 │  (3D points)   │  (hand chart)  │  (foot chart)  │
 │ 3D point map   │ Hand chart     │ Foot chart     │
 ├────────────────┼────────────────┴────────────────┘
 │  (ear chart)   │
 │ Ear points     │
 └────────────────┘
 Illustrations
 Watch each step, then try it yourself.
 ╭──────────────────────────────────────────────────╮
 │ [✚] First aid                                  6 │
 ├──────────────────────────────────────────────────┤
 │ CPR                                            › │
 │ 6 steps                                          │
 │ … (4 shown)                                      │
 │                 Show all 6 ⌄                     │  ← groups > 5 fold to 4
 ╰──────────────────────────────────────────────────╯
 ╭ [🩹] Bones … ╮  ╭ [💧] Blood … ╮  ╭ [🌡] Illness … ╮  ╭ Pregnancy … ╮
 Settings  (see settings.md)
```

Focused search, nothing typed:
```
 RECENT                                     Clear
 ╭──────────────────────────────────────────────────╮
 │ ⟲ femur                                       ↖  │  ← tap fills the field
 ╰──────────────────────────────────────────────────╯
 TRY SEARCHING
 (🔍 CPR) (🔍 Choking) (🔍 Stroke) (🔍 Burn) (🔍 Femur) …
```

- Two sections: Human body (anatomy systems; 2 rows, ▾ expands) and Reflex & acupressure (3D point map + charts).
- Tiles: card with a square thumbnail on a system-colour gradient + 2-line name.
  Chart tiles draw the chart; the 3D point map is drawn in SwiftUI (icon motif);
  system tiles are transparent PNGs from `scripts/render_body/tiles.sh`.
- Order of illustration groups: First aid, Bones, Blood, Illness, Pregnancy.

## Copy

| Key | EN | 中文 |
|---|---|---|
| search | Body parts, illnesses, procedures | 身体部位、疾病、操作 |
| body | Human body | 人体 |
| reflex | Reflex & acupressure | 反射区与穴位 |
| more | Show more (n) / Show less | 显示更多（n）/ 收起 |
