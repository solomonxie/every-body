# Settings

Second tab. Code: `src/app/(tabs)/settings.tsx`.

Built (v1): NAMES `[ English | 中文 | Both 双语 ]` · VIEWER background `[ Gray | White ]`,
Auto-rotate ─● · ABOUT: health disclaimer + sources inline, version. Theme and Quality below
are not built yet; Licenses/Disclaimer pages collapsed into the About cards.

```
 Settings
 ──────────────────────────────────────────────────────
 NAMES
 [ English | 中文 | BOTH ]
 APPEARANCE
 ╭──────────────────────────────────────────────────╮
 │ Theme              [ SYSTEM | Light | Dark ]     │
 ├──────────────────────────────────────────────────┤
 │ Viewer background         [ GRAY | White ]       │
 ╰──────────────────────────────────────────────────╯
 3D
 ╭──────────────────────────────────────────────────╮
 │ Auto-rotate on open                          ─●  │
 ├──────────────────────────────────────────────────┤
 │ Quality              [ AUTO | High | Low ]       │ ← Low: decimated meshes, no shadows
 ╰──────────────────────────────────────────────────╯
 ABOUT ⓘ
 ╭──────────────────────────────────────────────────╮
 │ Model data & licenses                         ›  │
 ├──────────────────────────────────────────────────┤
 │ Health disclaimer                             ›  │
 ├──────────────────────────────────────────────────┤
 │ Version                               1.0.0 (12) │
 ╰──────────────────────────────────────────────────╯
 ──────────────────────────────────────────────────────
     ○ Explore                    ◉ Settings
```
ABOUT ⓘ popover: "Free and offline. No account, no tracking."

All controls commit on change (local storage). Only one state.

## Licenses page

```
 ‹ Settings        Licenses
 Anatomy models
 Z-Anatomy, based on BodyParts3D © The Database
 Center for Life Science. CC BY-SA 4.0.
 Converted models: github.com/…/body-atlas-models  ›
 ─────────────────────────────────────────────────
 Open-source software                          (84) ›
```

## Disclaimer page

```
 ‹ Settings        Health disclaimer
 Body Atlas is for learning. It isn't medical
 advice. Reflex and acupoint effects describe
 traditional practice, not proven treatment.
 See a clinician for any health concern.
```

## Copy

| Key | String |
|---|---|
| `settings.names` | Names |
| `settings.theme` | Theme |
| `settings.background` | Viewer background |
| `settings.autoRotate` | Auto-rotate on open |
| `settings.quality` | Quality |
| `settings.licenses` | Model data & licenses |
| `settings.disclaimer` | Health disclaimer |

## Notes

Dropped the placeholder "Units" row — nothing in v1 is measured.
