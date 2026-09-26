# Settings

Last section of Home (no tab, no page). Code: `Sources/Screens/SettingsSection.swift`.

```
 Settings
 ╭──────────────────────────────────────────────────╮
 │ [🌐] Language          [ English | 中文 ]         │  ← one language, never mixed
 │ [👤] Person                                       │
 │ [ Infant | Toddler | Child | Adult | Senior ]     │  ← same value as the toolbar chip
 │ [⚥] Sex                [ Male | Female ]          │
 │ [🤰] Pregnant                               ─○    │  ← only for Female + Adult
 ╰──────────────────────────────────────────────────╯
 3D VIEWER
 ╭──────────────────────────────────────────────────╮
 │ [■] White background                        ─○    │
 │ [↻] Auto-rotate on open                     ─●    │
 ╰──────────────────────────────────────────────────╯
 🩺 For learning, not medical advice. In an emergency call 120 / 911.
 ⓘ Sources                                   Version 1.0
       └ popover: traditional-claim note + GB/T, WHO, ILCOR sources
```
Rows that don't fit (large type) stack the control under the label.

All controls commit on change (UserDefaults). Language defaults to the device language.
