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
 │ Reflex Map     │ Hand chart     │ Foot chart     │
 ├────────────────┼────────────────┴────────────────┘
 │  (ear chart)   │
 │ Ear points     │
 └────────────────┘
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

- Two sections: Human body (anatomy systems; 2 rows, ▾ expands) and Reflex & acupressure (3D point map + charts).
- Chart tiles draw the chart itself (no PNG); system tiles use rendered PNGs.
- Order of illustration groups: First aid, Bones, Blood, Illness, Pregnancy.

## Copy

| Key | EN | 中文 |
|---|---|---|
| search | Body parts, illnesses, procedures | 身体部位、疾病、操作 |
| body | Human body | 人体 |
| reflex | Reflex & acupressure | 反射区与穴位 |
| more | Show more (n) / Show less | 显示更多（n）/ 收起 |
