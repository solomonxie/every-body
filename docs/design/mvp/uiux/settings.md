# Settings

Last section of Home (no tab, no page). Code: `Sources/Screens/SettingsSection.swift`.

```
 Settings
 ╭──────────────────────────────────────────────────╮
 │ Language   [ English | 中文 ]                     │  ← one language, never mixed
 │ Person     [ Infant | Child | Adult | 65+ ]       │  ← same value as the toolbar chip
 │ Sex        [ Male | Female ]                      │
 │ Pregnant                                    ─○    │  ← only for Female + Adult
 │ White 3D background                         ─○    │
 │ Auto-rotate on open                         ─●    │
 ╰──────────────────────────────────────────────────╯
 Disclaimer (learning only; reflex claims are traditional; call 120 / 911)
 Sources · Version
```

All controls commit on change (UserDefaults). Language defaults to the device language.
