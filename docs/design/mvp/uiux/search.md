# Search

Full-height sheet. From Explore search field or Viewer 🔍. Matches EN, 中文, and pinyin.

```
▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
 ┌──────────────────────────────────────────┐
 │ 🔍 fem▌                               ✕  │  ( Cancel )
 └──────────────────────────────────────────┘
 PARTS                                            3
 Femur · 股骨                   Skeletal       ›
 Femoral artery · 股动脉        Circulatory    ›
 Femoral nerve · 股神经         Nervous        ›
 POINTS                                           0
 SYSTEMS                                          0
```
Opened from Viewer: current system's matches sort first. Sections with 0 hidden
(drawn here only to show the count rule).

Built: inline on Home (and `everybody://search`). Result sections are cards; each row
has a coloured icon per kind (▶ illustration · ▦ system · ✋ zone · ◎ point · 🧍 part).

## States

```
empty query   RECENT
              Kidney Reflex Zone (Foot)                    ›
              Femur                                        ›
              ( Clear recent )
no recents    TRY SEARCHING  (CPR) (Choking) (Stroke) (Femur) …   ← also shown under recents
no match      No matches for “femr”.
              Try the English or Chinese name.
```

## Interactions

| Target | Action | Result |
|---|---|---|
| part row | tap | Viewer (part's system), focus + Part card |
| point row | tap | Viewer (Reflex Map), pulse plays |
| system row | tap | Viewer (system) |
| Cancel / drag ▼ | — | close, query discarded |

## Copy

| Key | String |
|---|---|
| `search.placeholder` | Search parts, points, systems |
| `search.recent` | Recent |
| `search.clearRecent` | Clear recent |
| `search.noMatch` | No matches for “{q}”. |
| `search.noMatch.hint` | Try the English or Chinese name. |
