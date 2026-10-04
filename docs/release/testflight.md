# TestFlight external testing

App Store Connect → TestFlight → External Testing → **+** group → add the build. First build of a version goes through Beta App Review (~1 day).

## Test Information

Beta App Description (≤4000):

```
Every Body is an offline 3D atlas of the human body in English and Chinese. Tap any of about 200 bones, peel the body layer by layer (skin, muscles, organs, vessels, nerves), hide or isolate parts, and search in either language.

No account, no network; all content is built in.

What's in this beta:
• 3D skeleton, muscles, organs, vessels and nerves with per-part descriptions
• Hand, foot and ear reflex charts that pulse the linked organ
• 67 WHO-standard acupuncture points and the 14 meridians on the body
• 18 illustrated topics: first aid (CPR with hands-on practice, choking, bleeding, burns), blood sugar, blood pressure, pregnancy, posture and more
• English / 中文 search

Educational reference only, not medical advice. The figure is clothed by default (Clothing toggle on the full-body page).
```

Feedback Email: `you@example.com`

## Contact Information

| Field | Value |
|---|---|
| First Name | `Solomon` |
| Last Name | `Xie` |
| Phone number | TODO — yours, with country code (`+1 …`) |
| Email | `you@example.com` |

## Sign-In Information

Sign-in required: **off** (no account in the app). Leave User Name / Password blank.

Review Notes: paste the App Review Notes block from [listing.md](listing.md) if present.

## Per build: What to Test

```
Tap bones and organs on the 3D body, peel layers, isolate a part. Open the hand reflex chart and press a zone. Find an acupuncture point by name in both languages. Run the CPR topic through to the practice step. Report anything mislabeled, any 3D glitch or slowness, and your iPhone model, via TestFlight.
```
