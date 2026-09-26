# Home

The app's only root page (no tab bar). Code: `Sources/Screens/ExploreView.swift`.

```
 Body Atlas                                 [👤 Adult M ▾]
 ┌────────────────────────────────────────────────────┐
 │ 🔍 Body parts, illnesses, procedures               │  ← typing swaps sections for results
 └────────────────────────────────────────────────────┘
 Reflex maps & body
 ┌────────────────┬────────────────┬────────────────┐
 │  (3D points)   │  (hand chart)  │  (foot chart)  │
 │ Reflex Map     │ Hand chart     │ Foot chart     │
 ├────────────────┼────────────────┼────────────────┤
 │  (ear chart)   │  (skeleton)    │  (muscles)     │
 │ Ear points     │ Skeletal       │ Muscular       │
 └────────────────┴────────────────┴────────────────┘
              ▾ Show more (4)
 Illustrations — watch, then try
 ╭ First aid ───────────────────────────────────────╮
 │ CPR                                   5 steps ›  │
 │ Choking …                                        │
 ╰──────────────────────────────────────────────────╯
 ╭ Bones & setting … ╮  ╭ Blood … ╮  ╭ Illness … ╮  ╭ Pregnancy … ╮
 Settings
 ╭──────────────────────────────────────────────────╮
 │ Language  [ English | 中文 ]                      │
 │ Person    [ Infant | Child | Adult | 65+ ]        │
 │ Sex       [ Male | Female ]   ☐ Pregnant          │
 │ White 3D background ─○   Auto-rotate ─●           │
 ╰──────────────────────────────────────────────────╯
 disclaimer · sources · version
```

- Maps: reflex charts first, then body systems; 2 rows by default, ▾ expands.
- Chart tiles draw the chart itself (no PNG); system tiles use rendered PNGs.
- Order of illustration groups: First aid, Bones, Blood, Illness, Pregnancy.

## Copy

| Key | EN | 中文 |
|---|---|---|
| search | Body parts, illnesses, procedures | 身体部位、疾病、操作 |
| maps | Reflex maps & body | 反射图与人体 |
| more | Show more (n) / Show less | 显示更多（n）/ 收起 |
