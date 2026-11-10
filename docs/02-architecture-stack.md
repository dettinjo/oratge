# 02 — Architecture and technology stack

## 1. Why there must be a backend

1. **Quota:** ~100 forecast calls / month per key. Ten app opens a day with direct calls
   would use it up in three days.
2. **Key secrecy:** a key shipped in an APK can be extracted.
3. **History:** XEMA "now" data disappears from the cheap endpoints. Storing every fetch
   builds our own high-resolution archive for analysis for free.
4. **Alerts:** "wind 15–22 kn side-shore at Castelldefels tomorrow 16–19 h" has to be
   evaluated on a schedule, not when the app happens to be open.

```
 ┌───────────── homelab (Coolify) ─────────────┐        ┌─ Flutter (Android/iOS) ─┐
 │  oratge-api (FastAPI)                        │ HTTPS  │ Riverpod + widgets      │
 │   ├─ scheduler + budget governor ──► Meteocat│◄──────►│ drift (SQLite) cache    │
 │   ├─ gap filler ──────────────────► Open-Meteo        │ workmanager / BG fetch  │
 │   ├─ scoring engine (activities)             │        │ home_widget (native)    │
 │   ├─ alert evaluator ─► push (FCM → APNs)    │        └─────────────────────────┘
 │   └─ Postgres (+ TimescaleDB optional)       │
 │  key from Infisical: METEOCAT_API_KEY        │
 └──────────────────────────────────────────────┘
```

## 2. Quota budget (free plan, ⚠ verify numbers with `/quotes/v1/consum-actual`)

**Predicció — 100 / month**
| Job | Frequency | Calls/month |
|---|---|---|
| hourly forecast, home town | 1×/day (06:00) | 30 |
| beach forecast, main spot | 1×/day (06:00), Apr–Oct, or only on windy days | ≤ 30 |
| warnings (`smp/episodis-oberts`) | every 2nd day + on demand | 15 |
| on-demand pool (2nd town, summit, daily 8-day) | user-triggered, cached 24 h | 25 |

**Forecast source strategy (decided 2026-11-10, after the Claude Design handoff).**
The free plan includes forecasts, but the designed planners need about 14 forecast calls a
day (≈ 420/month): home hourly + daily, UV, warnings, two beaches × 3 dates, one summit ×
3 dates, a second town. So:
1. **Meteocat first, within the 100 calls:** home hourly + daily, warnings, and *today's*
   beach and summit forecasts for the user's favourite spots. Shown as the "Meteocat" entry
   in model agreement and preferred in the blend for today.
2. **Open-Meteo for everything Meteocat doesn't publish or the quota can't cover:** gusts,
   wave period / swell, hourly storm risk, freezing level, days 2–3 at secondary spots,
   hourly beyond day 3, other models and the ECMWF ensemble (51 members).
3. If Meteocat should cover every planner on its own: the paid professional plan, or a
   second free key.
Field-by-field mapping: `design/handoff/design/HANDOFF.md` → "Data sources per screen
element", and `docs/04-design-data-fit.md`.

**XEMA — 750 / month**
| Job | Frequency | Calls/month |
|---|---|---|
| `estacions/mesurades/{st}/{today}` for 2 key stations (home + main coastal) | hourly 07–21 h → 15×2 | ~900 ✗ |

That's over budget, so instead:
- **Daytime:** `variables/mesurades/{30|50}/ultimes` (wind + gust, all stations at once)
  every 2 h 08–20 → 7×2 = 14/day → **420**.
- **Night:** one `estacions/mesurades/{st}/{yesterday}` per *station-check* station (the
  design uses 5: el Raval, Viladecans, Sant Cugat, Gisclareny + the buoy) → 5/day →
  **150**. This back-fills the full 30-min record that the station check and history need.
- Temperature/RH (32/33) 1×/day → **60**. Buoys come with the `ultimes` calls for 92/93/96
  only when a surf spot is saved → ≤ **90**.
- Total ≈ 720.
- **History backfill** (rideable-hours heatmap) only from leftover quota:
  `variables/mesurades/{30|50}/{date}` covers all stations per day, so 2 calls per past
  day. 6 months ≈ 360 calls, spread over a few months. The UI says "since <first archived
  day>" until it's done.

**XDDE — 250:** only when warnings or sky symbols indicate storms: hourly fetch for the
current hour, capped at 8/day.

**Governor rules:** every job declares plan + cost; the governor reads the remaining
quota, spreads it over the days left in the month, and drops low-priority jobs first.
The cached value is always served, with its age ("wind 2 h ago").

**Scaling escape hatches:** a second free key (e.g. a separate "app" registration),
the paid professional plan, or more Open-Meteo for anything not official.

## 3. Backend stack
| Concern | Choice | Why |
|---|---|---|
| Language | **Python 3.12 + FastAPI** | fast to write, Joel knows Python, great data libs |
| Scheduling | APScheduler (in-process) | simple; one container |
| Storage | **Postgres** (Coolify-managed); readings table partitioned by month | time-series queries for history and analysis |
| HTTP | httpx + tenacity retries | |
| Analysis | numpy / pandas for stats, percentiles, climatology | |
| Push | **Firebase Cloud Messaging** (one API for Android and iOS; iOS requires APNs anyway). ntfy as an Android-only fallback for personal use | iOS background fetch is unreliable, so alerts must be server-pushed |
| Deploy | Docker → Coolify, secrets from Infisical, public HTTPS via Coolify proxy, app token auth | same pattern as other homelab apps |
| Tests | pytest + recorded Meteocat JSON fixtures (VCR) | quota-free testing |

The backend exposes **its own small, app-shaped API**, not a Meteocat mirror:
`GET /v1/home`, `/v1/spots/{id}`, `/v1/activities/{type}?spot=`, `/v1/map/now`,
`/v1/history/{station}`, `/v1/warnings`, `/v1/lightning?since=`.

## 4. App stack — Flutter (Android first, iOS ready)
| Concern | Choice |
|---|---|
| Framework | **Flutter (stable) + Dart 3**, one codebase for Android and iOS (web/desktop possible later) |
| UI | Custom design system on top of Material 3 widgets (own theme, own typography); platform-adaptive details only where expected (back gestures, pickers, haptics) |
| State / DI | **Riverpod** (with code generation); feature-first folders `lib/features/{today,activities,map,spots,history}` + `lib/core` |
| Navigation | go_router (deep links from notifications: `oratge://spot/castelldefels`) |
| Models / JSON | freezed + json_serializable; API client generated from the backend's OpenAPI schema (openapi-generator `dart-dio`) so the two never drift apart |
| Network | dio (retry, ETag / If-None-Match → cheap refreshes) |
| Offline | **drift** (SQLite): last payload per screen, shown instantly, then refreshed |
| Background | `workmanager` plugin (Android periodic work; iOS BGAppRefresh, best-effort) |
| Charts | **CustomPainter** for the signature visuals (wind band, wave bars, go-window, compass); **fl_chart** for plain history line and bar charts |
| Map | **flutter_map** + `vector_map_tiles` with a minimal OpenFreeMap / Protomaps style. Pure Dart, no API key, easy custom markers (wind arrows, lightning dots) |
| Widgets | `home_widget`: data is written from Dart, but the widget layout is native (Android: Glance/XML, iOS: WidgetKit/SwiftUI). This is the one place native code is unavoidable |
| Location | geolocator (coarse) → nearest municipality / representative station |
| i18n | flutter gen-l10n (ARB files): ca / es / en |
| Push | firebase_messaging + flutter_local_notifications |
| Quality | flutter_lints/very_good_analysis, unit + widget tests, golden tests for the chart painters |
| CI | GitHub Actions: analyze, test, build Android APK/AAB; iOS build on a macOS runner once needed (an iOS release needs an Apple developer account, $99/yr) |
| Min versions | Android 7 (API 24+), iOS 15+ |

Why Flutter fits this app: the design is fully custom (not stock Material/Cupertino), and
the core visuals are hand-drawn charts. Flutter's own rendering makes them pixel-identical
on both platforms with one CustomPainter each, and it holds 60/120 fps easily.

Trade-offs to accept: home-screen widgets and some background behaviour stay
platform-specific; app size is ~8–10 MB larger than native; iOS background refresh is not
guaranteed (hence server push).
