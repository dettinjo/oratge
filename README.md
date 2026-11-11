# Oratge (working name)

A minimalist cross-platform (Flutter: Android first, iOS ready) weather app for Catalonia built on the Meteocat API, tuned for wing
foiling, surfing, biking, running and hiking.

- [01 — API analysis](docs/01-api-analysis.md): every known endpoint, variables, quotas
- [02 — Architecture and stack](docs/02-architecture-stack.md): backend cache + quota
  governor on the homelab, Flutter app
- [03 — Design](docs/03-design.md): principles, screens, components, activity scoring
- [04 — Design vs data](docs/04-design-data-fit.md): Claude Design handoff checked against Meteocat
- Claude Design handoff (adapted): `design/handoff/design/HANDOFF.md`

## Status (2026-11-10)
| Part | State |
|---|---|
| **App** (`app/`, Flutter) | All screens from the Claude Design handoff: Today, Activities, 5 planners, Map (OSM, theme-toned), Spots, Spot detail, Profile, 10-step setup; light/dark/system; phone/tablet/desktop. 128 widget tests. Android APK verified on an Android 15 emulator against the live backend. |
| **Sync** (0.6) | Profile, setup progress and favourite places sync between devices through the backend (`/v1/sync`, newest change per setting wins, needs the server token). Server address and token can be set in the app (Profile → Sync and server), so builds don't need them baked in. |
| **Detailed map** (0.5) | Wind / Temp / Rain / Rain chance fields from a 10×14 Open-Meteo grid (0.25°, 48 h, `/v1/map/forecast`), animated wind particles and rain streaks, 48 h timeline with play and area rain bars, tap-anywhere probe (wind, gusts, temp, rain, chance), value labels when zoomed in, spot pins. |
| **Backend** (`backend/`, FastAPI) | Live on the home server via Coolify (`oratge-backend`, Tailscale only: `http://100.96.0.121:8199`, bearer token `ORATGE_API_TOKEN` in Infisical). Open-Meteo forecast/marine/models/ECMWF ensemble + archived high-res forecasts for history; Meteocat live since 2026-11-11 (key `METEOCAT_API_KEY` in Infisical + Coolify, valid to 14-11-2027): XEMA live readings (wind from el Prat / Cadí Nord where the spot's station has no anemometer) and official warnings per comarca; quota governor enforces a daily share of 100 forecast / 750 XEMA / 250 XDDE calls and syncs nightly with `consum-actual` (`/health` shows today's allowance); rating engine; forecast/observation archive for the station check. 32 tests. |
| **Install** | `oratge-0.2-arm64.apk` in Google Drive → `Oratge/`. Phone must be on Tailscale to reach the backend; otherwise the app falls back to bundled sample data. |

## Build and deploy
- App: `app/tool/build_apk.sh` (token from Infisical) · Mac: `app/tool/build_macos.sh` on a Mac with Xcode, or the `macOS app` GitHub Actions workflow (needs the repo on GitHub and an `ORATGE_TOKEN` secret) · web: `flutter build web --dart-define=ORATGE_API=…`
- Sample data from the design: `python3 app/tool/gen_sample.py` (same JSON contract the backend serves)
- Backend: `backend/deploy.sh <tag>` (tests → local image → Coolify PATCH + deploy → health check)

## Still open
1. **Station check** fills in once 7 days of XEMA observations are archived (from ~2026-11-17). Meteocat's terms: credit SMC as the data source and inform SMC if the app is ever published; don't pass raw data to third parties.
2. **Push alerts** need a Firebase project (FCM) on your account; thresholds are already in the profile.
3. **Add a spot / GPX import**: spots are fixed in `backend/oratge/spots.py` for now.
4. iOS build needs a Mac and an Apple developer account.

## Roadmap (original)
| Phase | Deliverable | Done when |
|---|---|---|
| 0 | Get the API key (all 5 plans); read the real quotas from `/quotes/v1/consum-actual`; record JSON fixtures for every endpoint; list buoy stations | fixtures committed, open ⚠ items in 01 resolved |
| 1 | Backend: ingest jobs, budget governor, Postgres, app API `/v1/home` | runs on Coolify for 7 days within quota |
| 2 | App shell: Today screen, 7-day forecast, offline cache, theme | installable debug APK (iOS build verified on a simulator later) |
| 3 | Spots + scoring engine + activity detail screens (wing and surf first) | scores match gut feeling on 10 real sessions |
| 4 | Map: stations, wind, lightning, warnings | |
| 5 | History and analysis, widgets, push alerts ("wing window tomorrow") | |
| 6 | Polish: i18n (ca/es/en), accessibility, Play Store internal track; TestFlight once an Apple developer account exists | |

## Open decisions
1. ~~Open-Meteo for gaps?~~ Decided 2026-11-10: Meteocat first within its quota; Open-Meteo for gusts, swell period, storm risk, freezing level, models/ensemble, and planners the quota can't cover (docs/02 §2).
2. Host the backend on the homelab (Coolify), public over HTTPS?
3. Home location and first spots (e.g. Barcelona, a flatwater wing spot, a surf beach)?
4. Personal use only, or Play Store later? Commercial use needs permission from Meteocat.
