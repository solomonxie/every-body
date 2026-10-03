# App Store Release

Bundle ID from `.env.local` (`IOS_BUNDLE_ID`) · iOS 18.0+ · iPhone only, portrait.

- [`listing.md`](listing.md) — step-by-step plan and every App Store Connect field, ready to paste
- [`privacy-policy.md`](privacy-policy.md) — the policy; its GitHub URL is the Privacy Policy URL
- `screenshots/6.9`, `screenshots/6.5` — ready, 10 shots (2026-10-02, simulator); recapture with `scripts/screenshot.sh install && scripts/screenshot.sh all /tmp/eb-shots && make screenshots SHOTS=/tmp/eb-shots` (list in `listing.md`)

Before the first build: `cp .env.local.example .env.local`, set `DEVELOPMENT_TEAM` and
`IOS_BUNDLE_ID`. Gitignored — this repo is public and account identifiers don't belong in it.

Upload a build: `make release` — archives, signs, uploads. Nothing in Xcode.
Build number is a timestamp unless you pass `BUILD=`.

Versioning: `MARKETING_VERSION` in `project.yml` is the user-visible version; bump it per
release. `CURRENT_PROJECT_VERSION` is set per upload by the script and never committed.
