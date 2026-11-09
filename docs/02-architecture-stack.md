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
 ┌───────────── homelab (Coolify) ─────────────┐        ┌──── Android ────┐
 │  oratge-api (FastAPI)                        │ HTTPS  │ Compose UI      │
 │   ├─ scheduler + budget governor ──► Meteocat│◄──────►│ Room cache      │
 │   ├─ gap filler ──────────────────► Open-Meteo        │ WorkManager     │
 │   ├─ scoring engine (activities)             │        │ Glance widgets  │
 │   ├─ alert evaluator ─► push (ntfy / FCM)    │        └─────────────────┘
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

**XEMA — 750 / month**
| Job | Frequency | Calls/month |
|---|---|---|
| `estacions/mesurades/{st}/{today}` for 2 key stations (home + main coastal) | hourly 07–21 h → 15×2 | ~900 ✗ |

That's over budget, so instead:
- **Daytime:** `variables/mesurades/{30|50}/ultimes` (wind + gust, all stations at once)
  every 2 h 08–20 → 7×2 = 14/day → **420**.
- **Night:** one `estacions/mesurades/{st}/{yesterday}` per key station → 2/day → **60**,
  which back-fills the full 30-min record.
- Temperature/RH (32/33) 2×/day → **120**. Buoys (92/93/96) 1×/day → **90**.
- Total ≈ 690.

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
| Push | **ntfy** (self-hostable, no Google dependency) — FCM later if needed | |
| Deploy | Docker → Coolify, secrets from Infisical, public HTTPS via Coolify proxy, app token auth | same pattern as other homelab apps |
| Tests | pytest + recorded Meteocat JSON fixtures (VCR) | quota-free testing |

The backend exposes **its own small, app-shaped API**, not a Meteocat mirror:
`GET /v1/home`, `/v1/spots/{id}`, `/v1/activities/{type}?spot=`, `/v1/map/now`,
`/v1/history/{station}`, `/v1/warnings`, `/v1/lightning?since=`.

## 4. Android stack
| Concern | Choice |
|---|---|
| Language / UI | **Kotlin + Jetpack Compose + Material 3** (dynamic colour off, own palette) |
| Architecture | single-activity, MVVM + unidirectional state; modules `:core`, `:data`, `:feature-*` |
| DI | Hilt |
| Network | Retrofit + kotlinx.serialization (or Ktor client) |
| Offline | Room: last payload per screen, shown instantly, then refreshed |
| Background | WorkManager (refresh widget data, every 30–60 min) |
| Charts | custom Compose `Canvas` for the signature visuals (wind band, wave bars, go-window); **Vico** for plain line and bar history charts |
| Map | **MapLibre** + a minimal vector style (OSM / OpenFreeMap tiles), no Google Maps key |
| Widgets | Glance (Compose for widgets) |
| Location | fused location (coarse) → nearest municipality / representative station |
| Min SDK | 26; target latest |
| CI | GitHub Actions: lint, unit tests, debug APK artefact |

Rejected: Flutter / React Native (the brief is Android-only, so native gives the best
Material 3, widget and performance story); calling Meteocat from the phone (quota, key).
