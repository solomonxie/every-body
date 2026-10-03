# Publishing Every Body — step by step

Every field below is ready to paste. `TODO` = only you can supply it.
App Store Connect paths start at **Apps → Every Body → Distribution →**.

| | |
|---|---|
| Bundle ID | `IOS_BUNDLE_ID` in the gitignored `.env.local` (`project.yml` holds only a placeholder) |
| SKU | `everybody-ios` |
| Version | `1.0` (`MARKETING_VERSION` in `project.yml`) |
| Build | timestamp, set by `make release` |
| Devices | iPhone only (`TARGETED_DEVICE_FAMILY = 1`) — no iPad screenshots needed |
| Min iOS | 18.0 |
| Lifecycle | SwiftUI `App` + `WindowGroup` (scene-based, no AppDelegate) — meets the iOS 27 UIScene requirement; launches on iPad in compatibility mode, where Review runs it |
| App size | ~46 MB unpacked (`Resources/Models` 30 MB, illustrations 6 MB) — well under the 200 MB cellular limit |
| Privacy Policy URL | `https://github.com/solomonxie/every-body/blob/master/docs/release/privacy-policy.md` |
| Support URL | `https://github.com/solomonxie/every-body/issues` |

---

## 1. Apple Developer account

- [ ] developer.apple.com → Account → membership **active** (paid, Individual is fine).
- [ ] App Store Connect → **Business** (Agreements, Tax, and Banking) → no pending agreement banner. Free app: no Paid Apps agreement or banking needed.

## 2. Xcode and signing

- [ ] Xcode → Settings → **Accounts** → signed in with the developer Apple ID; the team shows under it.
- [ ] `.env.local` has `DEVELOPMENT_TEAM` and `IOS_BUNDLE_ID` (template: `.env.local.example`). Gitignored — never commit it; the repo is public.
- [ ] `brew install xcodegen` once.

## 3. Bundle ID

Created by automatic signing on the first device build. Verify at developer.apple.com →
Certificates, Identifiers & Profiles → Identifiers → your `IOS_BUNDLE_ID`. No capabilities needed
(no iCloud, push, HealthKit, camera or location).

## 4. Run on the iPhone

- [ ] `make device`. Smoke-test: every home tile opens; Human body → Body → rotate, tap a bone, layers (figure stays clothed); Foot chart → press a zone; Acupuncture → a point card → Needling & safety; Illustrations → CPR → practice; search in English and 中文; Settings → Language.

## 5. Create the app in App Store Connect

**Apps → + → New App**

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | `Every Body: 3D Anatomy` (22/30) |
| Primary Language | English (U.S.) |
| Bundle ID | your `IOS_BUNDLE_ID` (dropdown) |
| SKU | `everybody-ios` |
| User Access | Full Access |

If the name is taken, in order: `Every Body – Anatomy Atlas` (26), `Every Body: Anatomy & Points` (28).
The on-device name stays `Every Body` (`CFBundleDisplayName`).

## 6. Listing content

Fill the pages in [App Store Connect pages](#app-store-connect-pages).

## 7. Screenshots

Ready — `docs/release/screenshots/6.9`, 10 shots (2026-10-02). Upload per [Screenshots](#screenshots).

## 8. Archive and upload

```
make release
```

Archives Release (`STORE=us`, one binary for every storefront), signs for the App Store and uploads
(`scripts/release-ios.sh`) — no Xcode Organizer. `make release BUILD=202610021830` pins the build
number; left off it is a timestamp. Warns if there are uncommitted changes.

Upload authenticates as the Apple ID in Xcode → Settings → Accounts. If it asks for credentials,
use an App Store Connect API key: append `-authenticationKeyPath <abs .p8> -authenticationKeyID <id>
-authenticationKeyIssuerID <issuer>` to the `-exportArchive` call in `scripts/release-ios.sh`.
Processing: 15–60 min, then an email "build has completed processing".

Fallback, Xcode GUI: `xcodegen generate`, open `EveryBody.xcodeproj`, set Team and bundle ID →
**Any iOS Device (arm64)** → Product → **Archive** → Organizer → **Distribute App** → App Store Connect → Upload.

## 9. TestFlight

- [ ] **TestFlight** → the build shows no "Missing Compliance" (see [Export compliance](#export-compliance)).
- [ ] Internal Testing → **+** group `Me` → add your Apple ID → install via the TestFlight app.
- [ ] Same smoke test as step 4 on the TestFlight build — the exact binary Apple reviews.

## 10. Submit

- [ ] `iOS App → 1.0 Prepare for Submission` → **Build** → **+** → pick the build.
- [ ] Every page in [App Store Connect pages](#app-store-connect-pages) filled; App Privacy published; age rating set.
- [ ] **Add for Review** → **Submit for Review**.

## 11. App Review

- Typical: 24–48 h. Waiting for Review → In Review → Pending Developer Release.
- Rejection → **Resolution Center**: reply there, or fix, `make release` (fresh build number), attach the build, resubmit.
- Likely questions:
  - **1.4.1 Physical harm / medical** — acupuncture needling depths, reflexology, first aid. Notes cover: educational, sourced, disclaimers in-app, no diagnosis or treatment.
  - **Nudity** — none: every figure wears underwear, which can't be removed (`Figure.clothingOptional = false`). See [Age rating](#general--app-information).
  - **2.1 Information Needed** — step 12.

## 12. Guideline 2.1 "Information Needed" (new developer accounts)

Apple wants a screen recording plus answers. The answers are the App Review Notes below — paste
them into the reply **and** into App Review → Notes.

Recording (the build Apple reviews, from TestFlight, on the iPhone, current iOS):
1. iPhone Settings → Control Center → add **Screen Recording**. Turn on Do Not Disturb. Swipe the app away.
2. Start recording, then launch Every Body from the Home Screen.
3. ~2 minutes:
   1. Home — scroll the sections (Acupuncture & reflexology, Human body, Illustrations, Posture, Pregnancy, Children, Settings).
   2. Human body → **Skeletal** — rotate, tap a bone (name card), Hide / Isolate / Undo.
   3. Back → **Body** — layers skin → muscles → bones; show the figure menus (age, appearance).
   4. **Foot chart** — press a zone, the pulse travels to its organ; note the "traditional" wording.
   5. **Acupuncture** — tap a point, the card with location and traditional uses, open **Needling & safety** (licensed practitioner only), the "Traditional claims — not medical advice" line.
   6. Illustrations → **CPR** — play the steps, then the hands-on practice on the 3D figure.
   7. Search `heart` → a result. Settings → Language → 中文 and back. Settings footer "For learning, not medical advice", **Sources**.
   8. Any 3D page → ⋯ → **Credits & licenses**.
4. Stop. Photos → trim → share the video.

Reply: **App Review** → the message → **Reply**, attach the video (or an unlisted link if too large), paste:

```
Hello, thank you for the review. Answers below, and the same text is now in the App Review Information notes.

1. Screen recording attached, captured on an iPhone running the latest iOS, starting from launch. The app has no account registration or login (so no account deletion flow), no user-generated content, no purchases and no network features.

[paste the App Review Notes block from PURPOSE AND AUDIENCE to the end]
```

## 13. Release

- [ ] **Pending Developer Release** → `1.0` page → **Release This Version**. Live within ~24 h.
- [ ] `git tag v1.0 && git push --tags`.

---

## Screenshots

**Ready** — captured 2026-10-02 on the iPhone 18 Pro simulator (iOS 27), English UI, light mode,
figures clothed. Upload `docs/release/screenshots/6.9/*.jpg` to the **iPhone 6.9" Display** slot
(`1320 × 2868`, the one Apple requires) in filename order; `6.5/` (`1284 × 2778`) is optional.
JPEG, no alpha.

| # | File | Screen | Launch args (`scripts/screenshot.sh shot`) |
|---|---|---|---|
| 01 | `01-full-body.jpg` | Full body, clothed figure | `-screen viewer/body` |
| 02 | `02-skeleton.jpg` | Skeleton, femur selected | `-screen viewer/skeletal -part femur-l` |
| 03 | `03-muscles.jpg` | Muscular system | `-screen viewer/muscular` |
| 04 | `04-organs.jpg` | Organs, heart card | `-screen viewer/organs -part heart` |
| 05 | `05-acupuncture.jpg` | Meridians, LI4 card with "not medical advice" | `-screen viewer/acupuncture -point acu-li4 -cardBottom YES` |
| 06 | `06-foot-chart.jpg` | Foot chart, heart zone → organ | `-screen reflex/foot -face sole -zone sole-heart` |
| 07 | `07-cpr.jpg` | CPR illustration | `-screen illustration/cpr` |
| 08 | `08-cpr-practice.jpg` | CPR 3D practice | `-screen illustration/cpr -trainer YES` |
| 09 | `09-posture.jpg` | Posture: long sitting | `-screen posture/sitting` |
| 10 | `10-home.jpg` | Home | (none) |

Recapture (boot a simulator first; launch arguments exist only in the `SCREENSHOTS` build, never in `make release`):

```
scripts/screenshot.sh install
scripts/screenshot.sh all /tmp/eb-shots
make screenshots SHOTS=/tmp/eb-shots
```

Optional: add a one-line caption band per shot later; plain captures are accepted.
App Preview video: skip for 1.0.

---

## App Store Connect pages

### `iOS App → 1.0 Prepare for Submission`

| Field | Value |
|---|---|
| Previews and Screenshots | [Screenshots](#screenshots) |
| Promotional Text | below |
| Description | below |
| Keywords | below |
| Support URL | `https://github.com/solomonxie/every-body/issues` |
| Marketing URL | leave blank |
| Version | `1.0` |
| Copyright | `2026 solomonxie` |
| Routing App Coverage File | leave blank |
| Build | the uploaded build (step 10) |
| App Review → Sign-In Required | Off |
| App Review → Contact First / Last Name | TODO |
| App Review → Phone | TODO (with country code, e.g. `+1 …`) |
| App Review → Email | TODO |
| App Review → Notes | below |
| App Review → Attachment | none |
| Version Release | **Manually release this version** |

Promotional Text (157/170). No price wording ("free", "no ads", "no subscription") in name, subtitle or promotional text — Guideline 2.3.7; the description may say it:

```
Turn a 3D body, peel back skin to bone, press a foot reflex zone and watch where it leads, then practise CPR on the figure. Works offline, no account needed.
```

Description:

```
Every Body is a free, offline way to explore the human body — every system in 3D, the hand, foot and ear reflex maps, acupuncture points, and how common illnesses and first aid work. In English and 中文.

Every feature is watch, then try: an animation, plus something to drag, tap, hold or compare.

3D ANATOMY
• A real skeleton with about 200 tappable bones, plus muscles, organs, blood vessels and nerves
• Peel the body layer by layer, tap any part for its name, hide, fade or isolate it
• Bend the shoulder, elbow and knee and watch the muscles work
• Men and women, infant to 65+, pregnancy, six appearances

REFLEX MAPS AND ACUPUNCTURE
• Hand, foot and ear charts drawn to the standard maps (GB/T 13734 ear points)
• Press a zone and a pulse travels to the organ it is traditionally linked with
• 67 commonly used acupuncture points at their WHO standard locations, and the 14 meridians on the 3D body
• Each point: code, names, how to find it, traditional uses, and safety cautions for pregnancy and age

ILLUSTRATIONS
• First aid: CPR with hands-on practice, choking, severe bleeding, burns, recovery position, sprains
• Blood sugar, blood pressure and blood fats explained
• Illnesses: stroke, heart attack, cold vs flu, asthma, reflux, kidney stones
• Pregnancy: how the baby grows, warning signs, sleep position, labour and birth
• Posture: sitting, standing, phones and laptops

ALSO
• Search everything in English or Chinese
• No account, no network connection needed, no ads, no tracking

FOR LEARNING, NOT MEDICAL ADVICE
Every Body is an educational reference. It does not diagnose or treat any condition. Reflex and acupuncture effects describe traditional practice, not proven treatment; acupuncture should only be performed by a licensed practitioner. Talk to a doctor before making health decisions. In an emergency, call your local emergency number.

3D anatomy adapted from Z-Anatomy (CC BY-SA 4.0, from BodyParts3D); figures made with MakeHuman (CC0), faces and hair after Blender Studio's Snow and Rain (CC BY 4.0). Full credits are in the app.
```

Keywords (98/100 — "every", "body", "3D", "anatomy" omitted, the name indexes them):

```
acupuncture,acupoints,reflexology,skeleton,muscles,organs,first aid,cpr,meridian,biology,human,ear
```

App Review Notes:

```
PURPOSE AND AUDIENCE
Every Body is a free educational atlas of the human body for students, curious adults, parents and people learning first aid or traditional Chinese medicine. It shows 3D anatomy (skeleton, muscles, organs, vessels, nerves), hand/foot/ear reflex charts, 67 acupuncture points with their meridians, and step-by-step illustrations of first aid, common illnesses, pregnancy and posture. English and Simplified Chinese, switchable in Settings.

HOW TO USE IT
No account or login. Everything is on the home screen:
- Human body → Skeletal: rotate with one finger, pinch to zoom, tap a bone for its name; Hide / Fade / Isolate / Undo.
- Human body → Body: the full figure; the layer pills go from skin to bone; the menu pills (hold) pick age, sex, appearance and body shape.
- Foot chart / Hand chart / Ear points: press a zone; a pulse travels to the organ it is traditionally linked with.
- Acupuncture: tap a point for its card (location, traditional uses, cautions); "Needling & safety" opens the safety notes.
- Illustrations → CPR: play the steps, then the hands-on practice on the 3D figure (compressions scored for rate and depth).
- Search field at the top; Settings (language, sources) at the bottom; any 3D page → ⋯ → Credits & licenses.

MEDICAL CONTENT (Guideline 1.4.1)
The app is an educational reference, not a medical device. It takes no health data, does no diagnosis, gives no dosing or personalised treatment advice and makes no measurements. Disclaimers appear in the app: Settings footer "For learning, not medical advice. In an emergency, call your local emergency number." (same in Chinese), on every acupuncture and reflex card "Traditional claims — not medical advice", and the needling notes open with "Only by a licensed practitioner, with sterile, single-use needles" before any needling depth. Reflex and acupoint effects are described as traditional practice, not proven treatment. Sources are listed in Settings → Sources: WHO Standard Acupuncture Point Locations (2008), GB/T 13734-2008 ear points, ILCOR / Red Cross first-aid guidance; illness and pregnancy notes cite their guidance in each illustration.

ANATOMICAL FIGURE
Every 3D figure, adult or child, wears opaque modest underwear on every screen; there is no option to remove it. The figures are non-sexual, in the standard anatomical pose, with no genitals modelled. Inner layers (muscles, bones, organs) are anatomical models, not skin.

EXTERNAL SERVICES
None. The app makes no network requests: no analytics, advertising, crash reporting, accounts, payments or AI services. The only links are the source and licence URLs in Credits & licenses, which open in Safari.

THIRD-PARTY CONTENT
3D anatomy is adapted from Z-Anatomy (CC BY-SA 4.0; derived from BodyParts3D, CC BY-SA 2.1 JP; brain after Brainder, CC BY-SA 3.0; cranial nerves University of Dundee, CC BY 4.0). Skin figures and illustration people are made with MakeHuman/MPFB assets (CC0); faces and hair after Blender Studio's Snow and Rain (CC BY 4.0). All licences permit commercial redistribution; Z-Anatomy parts marked non-commercial are not used. Attribution is in the app (Credits & licenses) and the adapted files are published under the same licences in the public source repository.

REGIONAL DIFFERENCES
The app works the same in every region. The Settings footer says to call the local emergency number; the first-aid illustrations show 911 in English and 120 in Chinese as examples.

REGULATION
Every Body is not a medical device and makes no diagnostic or therapeutic claims. It does not connect to any health service, store health records or sell anything.

All content ships inside the app and works offline. We operate no server and receive no user data.
```

What's New: not shown for a first version. From 1.1 on, write it here.

### `General → App Information`

| Field | Value |
|---|---|
| Name | `Every Body: 3D Anatomy` |
| Subtitle (29/30) | `Anatomy, acupoints, first aid` |
| Category — Primary | Education |
| Category — Secondary | Reference |
| Content Rights | **Yes**, it contains third-party content — **and I have the necessary rights** (licences below) |
| Age Rating | **Edit** → answers below → expected result **16+** |
| License Agreement | Apple standard EULA (default) |
| Privacy Policy URL | as above |

Primary Education over Medical: it is a learning atlas, and Medical draws the stricter 1.4.1 review.

Content Rights — what the "Yes" rests on (`LICENSES/THIRD_PARTY.md`, `Resources/Models/LICENSE.md` ships in the app):

| Source | Licence | Commercial App Store OK? | Condition, and status |
|---|---|---|---|
| Z-Anatomy (skeleton, muscles, organs, vessels, nerves) | CC BY-SA 4.0 | Yes | Attribution: in-app Credits. ShareAlike: adapted files released under CC BY-SA 4.0 and public on GitHub; app resources aren't DRM-encrypted |
| BodyParts3D (via Z-Anatomy) | CC BY-SA 2.1 JP | Yes | Credited in-app |
| Brainder brain surface | CC BY-SA 3.0 | Yes | Credited in-app |
| Univ. of Dundee cranial nerves | CC BY 4.0 | Yes | Credited in-app |
| Z-Anatomy kidney (CC BY-NC), inner ear (CC BY-NC-SA) | NC | **No** | Not used — skipped by `build_internals.py` |
| MakeHuman / MPFB assets (figures, illustration people, clothes) | CC0 1.0 | Yes | None; credited anyway |
| Blender Studio Snow and Rain (faces, hair) | CC BY 4.0 | Yes | Credited in-app with the required "© Blender Foundation \| studio.blender.org" line |
| Blender, MPFB2 code | GPL | n/a | Tools only, no code ships |

No blocker. In-app Credits link each source and its licence (CC BY-SA 4.0, 3.0, 2.1 JP, CC BY 4.0,
CC0 1.0, Blender's GPL) — CC 4.0 asks for the licence URI.

Age rating questionnaire — every answer:

| Section | Answer | Why |
|---|---|---|
| Parental controls / age assurance | No | |
| Unrestricted web access | No | no browser; Credits links open Safari |
| User-generated content | No | |
| Messaging and chat | No | |
| Advertising | No | |
| Violence (cartoon, realistic, graphic), profanity, horror | None | first-aid wounds are schematic |
| Mature or suggestive themes | **Infrequent** | labour and birth, stillbirth risk, heart attack and stroke |
| Sexual content or nudity | None | every figure wears opaque underwear, not removable; standard anatomical pose |
| Graphic sexual content and nudity | None | |
| Alcohol, tobacco, drugs | None | only a caution ("not after alcohol") and "blood thinners" |
| Medical or treatment information | **Frequent** | first aid, illnesses, acupuncture needling depths — core content |
| Health or wellness topics | **Yes** | posture, pregnancy sleep, blood sugar / pressure / fats |
| Gambling, simulated gambling, contests, loot boxes | None / No | |
| Made for Kids | No | |

Expected: **16+**, driven by Frequent medical information alone (nudity is None). Answering
"Infrequent" would give 13+, but medical content is the core of the app — keep it honest.
Clothing is fixed on in code: `Figure.clothingOptional = false` (`Sources/Body/Figure.swift`). Setting it
`true` brings back the full-body page's Clothing toggle and see-through underwear on the acupuncture
view — then nudity must be re-answered and Review may reject.

Regional (Korea, China Mainland, Vietnam) — leave unset.
**Digital Services Act** trader status: **Not a trader** (free, no monetization).

### `App Store → Trust & Safety → App Privacy`

| Field | Value |
|---|---|
| Privacy Policy URL | as above |
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** |

Then **Publish**. The label shows "Data Not Collected".

True while there is no network code and no SDK. The app only reads its bundled files and saves the
language choice in `UserDefaults`. Re-check before each submission:

```
grep -rnE "URLSession|URLRequest|NWConnection|WKWebView|analytics|firebase|sentry" Sources
```

`Resources/PrivacyInfo.xcprivacy` is the matching privacy manifest: no tracking, no collected
data, one required-reason API (`UserDefaults`, CA92.1). No usage strings: no camera, photos,
microphone, location, HealthKit, motion or contacts.

### `App Store → Trust & Safety → App Accessibility`

Skip for 1.0 rather than over-claim (the 3D views aren't fully VoiceOver-navigable).

### `App Store → Monetization → Pricing and Availability`

| Field | Value |
|---|---|
| Base Country or Region | United States (USD) |
| Price | **Free** ($0.00) |
| Availability | All countries or regions **except China mainland** — see below |
| Tax Category | App Store software (default) |
| iPhone and iPad Apps on Apple Silicon Macs | **Off** for 1.0 (3D touch controls untested on Mac) |
| Apple Vision Pro | Off |

China mainland: App Store Connect asks for an **ICP Filing Number** (MIIT app filing) for any
app sold there, which an individual developer outside China usually can't get. Leave it
unchecked for 1.0. TODO: add it later if you obtain a filing; the 简体中文 listing still serves
Hong Kong, Taiwan, Singapore and Chinese-language users elsewhere.
`STORE=cn` (`AppStoreRegion`) is baked in at build time but no code reads it yet; the release
build uses `us`.

### Not needed for 1.0

In-App Purchases, Subscriptions, In-App Events, Custom Product Pages, Product Page
Optimization, Promo Codes, Game Center, Featuring Nominations.

---

## Export compliance

Nothing to fill in. `ITSAppUsesNonExemptEncryption = false` (set in `project.yml`) answers it at
upload — the app makes no network connections and uses no cryptography (no CryptoKit / CommonCrypto).
Verify: TestFlight → the build is **not** marked "Missing Compliance".
Only if it is: **Manage** → **None of the algorithms mentioned above**.

---

## Optional: 简体中文 localization

The app ships Chinese (in-app language switch; `CFBundleLocalizations` lists `zh-Hans` so the store
shows it). App Store Connect → App Information → language dropdown (top right) → **Add Chinese
(Simplified)**, then on the `1.0` page switch to it.

| Field | Value |
|---|---|
| Name | `Every Body：3D 人体` |
| Subtitle | `人体解剖·针灸穴位·急救图解` |
| Privacy Policy URL | same |
| Keywords (47 chars) | `人体,解剖,骨骼,肌肉,器官,穴位,针灸,经络,反射区,足底,耳穴,急救,心肺复苏,孕期,生理` |
| Screenshots | reuse English ones, or upload the 中文 set if you capture one |

Promotional Text:

```
旋转 3D 人体，从皮肤一层层看到骨骼；按下足底反射区，看它通向哪个器官；在人体上练习心肺复苏。离线可用，无需账号。
```

Description:

```
Every Body 是一款免费、离线的人体探索应用——3D 呈现人体各系统、手足耳反射区、针灸穴位，以及常见疾病与急救的原理。中英双语。

每个功能都是“先看，再动手”：一段动画，加上可以拖动、点按、长按或对比的互动。

3D 人体解剖
• 真实骨骼，约 200 块骨头可点选；另有肌肉、器官、血管与神经
• 一层层剥开人体，点任意部位看名称，可隐藏、半透明或单独显示
• 弯曲肩、肘、膝，看肌肉如何发力
• 男性与女性，婴儿到 65 岁以上，孕期，五种外貌

反射区与针灸
• 手部、足底、耳穴图，依照标准图谱绘制（耳穴依 GB/T 13734）
• 按下反射区，一道脉冲流向传统上与之对应的器官
• 67 个常用穴位，按 WHO 标准定位，14 条经络画在 3D 人体上
• 每个穴位：编号、名称、取穴方法、传统主治，以及孕期与年龄相关的注意事项

图解
• 急救：心肺复苏（可动手练习）、气道异物、严重出血、烧烫伤、复苏体位、扭伤
• 血糖、血压、血脂讲解
• 疾病：中风、心梗、感冒与流感、哮喘、反流、肾结石
• 孕期：胎儿发育、危险信号、睡姿、分娩
• 姿势：坐、站、手机与电脑

其他
• 中英文搜索全部内容
• 无需账号，无需联网，无广告，无追踪

仅供学习，不构成医疗建议
Every Body 是教育参考工具，不诊断、不治疗任何疾病。反射区与穴位功效为传统说法，未经证实；针刺须由有资质的医师操作。做健康决定前请咨询医生。紧急情况请拨打当地急救电话。

3D 解剖模型改编自 Z-Anatomy（CC BY-SA 4.0，源自 BodyParts3D）；人物以 MakeHuman（CC0）制作，脸型与发型取自 Blender Studio 的 Snow 与 Rain（CC BY 4.0）。完整致谢见应用内。
```
